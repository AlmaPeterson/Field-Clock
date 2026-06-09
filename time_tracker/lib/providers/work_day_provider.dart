import 'package:flutter/foundation.dart';
import '../models/work_day.dart';
import '../models/task.dart';
import '../database/dao/work_day_dao.dart';
import '../database/dao/task_dao.dart';
import '../utils/time_utils.dart';

class WorkDayProvider extends ChangeNotifier {
  final WorkDayDao _workDayDao = WorkDayDao();
  final TaskDao _taskDao = TaskDao();

  WorkDay? _today;
  List<Task> _todayTasks = [];
  Task? _activeTask;

  WorkDay? get today => _today;
  List<Task> get todayTasks => _todayTasks;
  Task? get activeTask => _activeTask;
  bool get isClockedIn => _today?.isClockedIn ?? false;
  bool get hasActiveTask => _activeTask != null;

  Future<void> loadToday() async {
    _today = await _workDayDao.getToday();
    if (_today != null) {
      _todayTasks = await _taskDao.getByWorkDay(_today!.id!);
      _activeTask = await _taskDao.getActiveTask(_today!.id!);
    }
    notifyListeners();
  }

  Future<void> clockIn({String? photoPath, String? location, int? jobId}) async {
    final now = DateTime.now();
    final day = WorkDay(
        date: now,
        jobId: jobId,
        clockInTime: now,
        clockInPhoto: photoPath,
        clockInLocation: location,
    );
    final id = await _workDayDao.insert(day);
    _today = day.copyWith(id: id);
    _todayTasks = [];
    _activeTask = null;
    notifyListeners();
  }

  Future<void> clockOut({String? photoPath, String? location}) async {
    if (_today == null) return;
    final now = DateTime.now();
    final raw = now.difference(_today!.clockInTime!);
    final rounded = TimeUtils.roundToNearest15(raw);
    final updated = _today!.copyWith(
      clockOutTime: now,
      clockOutPhoto: photoPath,
      clockOutLocation: location,
      totalMinutesRaw: raw.inMinutes,
      totalMinutesRounded: rounded.inMinutes,
    );
    await _workDayDao.update(updated);
    _today = updated;
    notifyListeners();
  }

  Future<Task> startTask({String? photoPath, String? location}) async {
    if (_today == null) throw Exception('Not clocked in');
    final task = Task(
      workDayId: _today!.id!,
      name: 'Unnamed Task',
      startTime: DateTime.now(),
      startPhoto: photoPath,
      startLocation: location,
    );
    final id = await _taskDao.insert(task);
    _activeTask = task.copyWith(id: id);
    _todayTasks = await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
    return _activeTask!;
  }

  Future<void> endTask({
    required String name,
    String? photoPath,
    String? location,
    String? notes,
    double hourlyRate = 0.0,
  }) async {
    if (_activeTask == null) return;
    final now = DateTime.now();
    final raw = now.difference(_activeTask!.startTime);
    final rounded = TimeUtils.roundToNearest15(raw);
    final updated = _activeTask!.copyWith(
      name: name,
      endTime: now,
      endPhoto: photoPath,
      endLocation: location,
      notes: notes,
      durationMinutesRaw: raw.inMinutes,
      durationMinutesRounded: rounded.inMinutes,
      hourlyRate: hourlyRate,
    );
    await _taskDao.update(updated);
    _activeTask = null;
    _todayTasks = await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await _taskDao.update(task);
    _todayTasks = await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }
}