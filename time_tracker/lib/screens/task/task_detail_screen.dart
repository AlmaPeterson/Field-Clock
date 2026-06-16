import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/task.dart';
import '../../models/task_session.dart';
import '../../models/task_photo.dart';
import '../../database/dao/task_dao.dart';
import '../../database/dao/task_session_dao.dart';
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

class _TaskDetailScreenState
    extends State<TaskDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _divisionSearchController;
  String? _selectedDivision;
  List<String> _filteredDivisions = Divisions.all;
  bool _showDivisionList = false;
  List<TaskSession> _sessions = [];
  List<TaskPhoto> _photos = [];
  bool _saving = false;

  final _taskDao = TaskDao();
  final _taskSessionDao = TaskSessionDao();
  final _taskPhotoDao = TaskPhotoDao();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.task.name);
    _notesController = TextEditingController(
        text: widget.task.notes ?? '');
    _divisionSearchController = TextEditingController(
        text: widget.task.division ?? '');
    _selectedDivision = widget.task.division;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _divisionSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.task.id == null) return;
    final sessions =
        await _taskSessionDao.getByTask(widget.task.id!);
    final photos =
        await _taskPhotoDao.getByTask(widget.task.id!);
    setState(() {
      _sessions = sessions;
      _photos = photos;
    });
  }

  int get _totalMinutes => _sessions
      .where((s) => !s.isActive)
      .fold(0,
          (sum, s) => sum + s.durationMinutesRounded);

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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = widget.task.copyWith(
      name: _nameController.text.trim().isEmpty
          ? 'Unnamed Task'
          : _nameController.text.trim(),
      division: _selectedDivision,
      notes: _notesController.text.trim(),
    );
    await _taskDao.update(updated);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirm = await _confirmDialog(
      title: 'Delete Task?',
      message: 'This cannot be undone.',
      destructive: true,
    );
    if (confirm != true) return;
    if (widget.task.id != null) {
      await _taskSessionDao
          .deleteByTask(widget.task.id!);
      await _taskPhotoDao
          .deleteByTask(widget.task.id!);
      await _taskDao.delete(widget.task.id!);
    }
    if (mounted) Navigator.pop(context, true);
  }

  // ── Session editing ──────────────────────────────

  Future<void> _addSession() async {
    final result =
        await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (_) =>
          _AddSessionDialog(taskId: widget.task.id!),
    );
    if (result == null) return;
    final start = result['start'];
    final end = result['end'];
    if (start == null) return;
    int raw = 0;
    int rounded = 0;
    if (end != null) {
      final d = end.difference(start);
      raw = d.inMinutes;
      rounded =
          TimeUtils.roundToNearest15(d).inMinutes;
    }
    await _taskSessionDao.insert(TaskSession(
      taskId: widget.task.id!,
      startTime: start,
      endTime: end,
      durationMinutesRaw: raw,
      durationMinutesRounded: rounded,
    ));
    await _load();
  }

  Future<void> _editSession(TaskSession s) async {
    final result =
        await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (_) => _EditSessionDialog(session: s),
    );
    if (result == null) return;
    final start = result['start'] ?? s.startTime;
    final end = result['end'] ?? s.endTime;
    int raw = 0;
    int rounded = 0;
    if (end != null) {
      final d = end.difference(start);
      raw = d.inMinutes;
      rounded =
          TimeUtils.roundToNearest15(d).inMinutes;
    }
    await _taskSessionDao.update(TaskSession(
      id: s.id,
      taskId: s.taskId,
      startTime: start,
      startPhoto: s.startPhoto,
      endTime: end,
      endPhoto: s.endPhoto,
      durationMinutesRaw: raw,
      durationMinutesRounded: rounded,
    ));
    await _load();
  }

  Future<void> _deleteSession(TaskSession s) async {
    final confirm = await _confirmDialog(
      title: 'Delete Session?',
      message: 'This time entry will be removed.',
      destructive: true,
    );
    if (confirm != true) return;
    await _taskSessionDao.delete(s.id!);
    await _load();
  }

  // ── Photos ───────────────────────────────────────

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
    final id = await _taskPhotoDao.insert(photo);
    setState(() =>
        _photos.add(photo.copyWith(id: id)));
  }

  Future<String?> _showPhotoSourceDialog() =>
      showModalBottomSheet<String>(
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
                title: const Text(
                    'Upload from Gallery'),
                onTap: () =>
                    Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        ),
      );

  Future<void> _deletePhoto(TaskPhoto photo) async {
    await _taskPhotoDao.delete(photo.id!);
    setState(() => _photos
        .removeWhere((p) => p.id == photo.id));
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
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel')),
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
                              .primary),
                )),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color;
    final bodyColor =
        Theme.of(context).textTheme.bodyLarge?.color;
    final surfaceAlt =
        Theme.of(context).dividerColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context)
                    .colorScheme
                    .error),
            onPressed: _delete,
          ),
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
          // ── Name ────────────────────────────────────
          _Label('TASK NAME'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: bodyColor),
            decoration: const InputDecoration(
                hintText:
                    'e.g. Framing — Master Bedroom'),
          ),
          const SizedBox(height: 20),

          // ── Division ────────────────────────────────
          _Label('DIVISION (OPTIONAL)'),
          const SizedBox(height: 8),
          if (_selectedDivision != null &&
              !_showDivisionList)
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
                            _selectedDivision!,
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
                            color: mutedColor,
                            size: 16),
                        onPressed: () {
                          _divisionSearchController
                              .clear();
                          _filterDivisions('');
                          setState(() =>
                              _selectedDivision =
                                  null);
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
                    maxHeight: 200),
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
                        _selectedDivision = div;
                        _showDivisionList = false;
                        _divisionSearchController
                            .text = div;
                      }),
                      child: Padding(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 14,
                            vertical: 10),
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

          // ── Notes ────────────────────────────────────
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

          // ── Sessions ─────────────────────────────────
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              _Label('TIME SESSIONS'),
              if (_totalMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    TimeUtils.formatDuration(Duration(
                        minutes: _totalMinutes)),
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('No sessions yet',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                  textAlign: TextAlign.center),
            ),
          ..._sessions.map((s) => _SessionRow(
                session: s,
                onEdit: () => _editSession(s),
                onDelete: s.isActive
                    ? null
                    : () => _deleteSession(s),
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
            onPressed: _addSession,
          ),
          const SizedBox(height: 20),

          // ── Photos ───────────────────────────────────
          _Label('PHOTOS'),
          const SizedBox(height: 8),
          Row(
            children: [
              _PhotoBtn(
                  label: 'Before',
                  color: AppColors.success,
                  onTap: () => _addPhoto('before')),
              const SizedBox(width: 8),
              _PhotoBtn(
                  label: 'After',
                  color: primary,
                  onTap: () => _addPhoto('after')),
              const SizedBox(width: 8),
              _PhotoBtn(
                  label: 'General',
                  color: Colors.blueGrey,
                  onTap: () => _addPhoto('general')),
            ],
          ),
          if (_photos.isNotEmpty) ...[
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
              itemCount: _photos.length,
              itemBuilder: (context, i) {
                final photo = _photos[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(8),
                      child: Image.file(
                          File(photo.photoPath),
                          fit: BoxFit.cover),
                    ),
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
                          photo.photoType
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w700),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () =>
                            _deletePhoto(photo),
                        child: Container(
                          padding:
                              const EdgeInsets.all(3),
                          decoration:
                              const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
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
          ],
          const SizedBox(height: 20),

          // ── Location ─────────────────────────────────
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

          // ── Delete ───────────────────────────────────
          OutlinedButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context)
                    .colorScheme
                    .error),
            label: Text('Delete Task',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .error),
              padding: const EdgeInsets.symmetric(
                  vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12)),
            ),
            onPressed: _delete,
          ),
          const SizedBox(height: 32),
        ],
      ),
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
}

// ── Session row ───────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final TaskSession session;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _SessionRow({
    required this.session,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color;

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
                    session.endTime != null
                        ? '${TimeUtils.formatTime(session.startTime)} → ${TimeUtils.formatTime(session.endTime!)}'
                        : '${TimeUtils.formatTime(session.startTime)} → Active',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  if (!session.isActive)
                    Text(
                      TimeUtils.formatDuration(
                          session.durationRounded),
                      style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600),
                    ),
                ],
              ),
            ),
            IconButton(
              icon:
                  Icon(Icons.edit, size: 18, color: muted),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (onDelete != null) ...[
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
          ],
        ),
      ),
    );
  }
}

// ── Add session dialog ────────────────────────────────────────────────────────

class _AddSessionDialog extends StatefulWidget {
  final int taskId;
  const _AddSessionDialog({required this.taskId});

  @override
  State<_AddSessionDialog> createState() =>
      _AddSessionDialogState();
}

class _AddSessionDialogState
    extends State<_AddSessionDialog> {
  DateTime? _start;
  DateTime? _end;

  Future<void> _pick(bool isStart) async {
    final base = isStart
        ? (_start ?? DateTime.now())
        : (_end ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    final dt = DateTime(base.year, base.month,
        base.day, picked.hour, picked.minute);
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  int get _rounded {
    if (_start == null || _end == null) return 0;
    final d = _end!.difference(_start!);
    return TimeUtils.roundToNearest15(d).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

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
            Text('ADD SESSION',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge),
            const SizedBox(height: 20),
            _DialogTimeRow(
              label: 'Start',
              time: _start,
              color: AppColors.success,
              onTap: () => _pick(true),
            ),
            const SizedBox(height: 10),
            _DialogTimeRow(
              label: 'End',
              time: _end,
              color: primary,
              onTap: () => _pick(false),
            ),
            if (_rounded > 0) ...[
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
                          Duration(minutes: _rounded)),
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700),
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
                    onPressed: _start == null
                        ? null
                        : () =>
                            Navigator.pop(context, {
                          'start': _start,
                          'end': _end,
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

// ── Edit session dialog ───────────────────────────────────────────────────────

class _EditSessionDialog extends StatefulWidget {
  final TaskSession session;
  const _EditSessionDialog({required this.session});

  @override
  State<_EditSessionDialog> createState() =>
      _EditSessionDialogState();
}

class _EditSessionDialogState
    extends State<_EditSessionDialog> {
  late DateTime _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.session.startTime;
    _end = widget.session.endTime;
  }

  Future<void> _pick(bool isStart) async {
    final base =
        isStart ? _start : (_end ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    final dt = DateTime(base.year, base.month,
        base.day, picked.hour, picked.minute);
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  int get _rounded {
    if (_end == null) return 0;
    final d = _end!.difference(_start);
    if (d.isNegative) return 0;
    return TimeUtils.roundToNearest15(d).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

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
            _DialogTimeRow(
              label: 'Start',
              time: _start,
              color: AppColors.success,
              onTap: () => _pick(true),
            ),
            const SizedBox(height: 10),
            _DialogTimeRow(
              label: 'End',
              time: _end,
              color: primary,
              onTap: widget.session.endTime != null
                  ? () => _pick(false)
                  : null,
            ),
            if (_rounded > 0) ...[
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
                          Duration(minutes: _rounded)),
                      style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700),
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
                      'start': _start,
                      'end': _end,
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelLarge);
}

class _DialogTimeRow extends StatelessWidget {
  final String label;
  final dynamic time;
  final Color color;
  final VoidCallback? onTap;

  const _DialogTimeRow({
    required this.label,
    required this.time,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: time != null && canTap
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
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canTap
                        ? color
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color)),
              ],
            ),
            Row(
              children: [
                Text(
                  time != null
                      ? TimeUtils.formatTime(time)
                      : 'Tap to set',
                  style: TextStyle(
                    color: time != null && canTap
                        ? color
                        : Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  canTap
                      ? Icons.edit
                      : Icons.lock_outline,
                  size: 14,
                  color: canTap
                      ? color
                      : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton.icon(
          icon: Icon(Icons.add_a_photo,
              size: 14, color: color),
          label: Text(label,
              style: TextStyle(
                  color: color, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            side:
                BorderSide(color: color.withOpacity(0.6)),
            padding: const EdgeInsets.symmetric(
                vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(10)),
          ),
          onPressed: onTap,
        ),
      );
}