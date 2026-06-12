import 'package:flutter/foundation.dart';
import '../models/work_day.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../database/dao/work_day_dao.dart';
import '../database/dao/task_dao.dart';
import '../database/dao/session_dao.dart';
import '../database/database_helper.dart';
import '../utils/time_utils.dart';

class WorkDayProvider extends ChangeNotifier {
  final WorkDayDao _workDayDao = WorkDayDao();
  final TaskDao _taskDao = TaskDao();
  final SessionDao _sessionDao = SessionDao();

  WorkDay? _today;
  List<Task> _todayTasks = [];
  List<Session> _todaySessions = [];
  Task? _activeTask;
  Session? _activeSession;

  WorkDay? get today => _today;
  List<Task> get todayTasks => _todayTasks;
  List<Session> get todaySessions => _todaySessions;
  Task? get activeTask => _activeTask;
  Session? get activeSession => _activeSession;

  bool get isClockedIn => _activeSession != null;
  bool get hasClockedInToday => _today != null;
  bool get hasActiveTask => _activeTask != null;

  // Total session minutes for today (rounded)
  int get totalSessionMinutes {
    return _todaySessions
        .where((s) => !s.isActive)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  Future<void> loadToday() async {
    _today = await _workDayDao.getToday();
    if (_today != null) {
      _todayTasks = await _taskDao.getByWorkDay(_today!.id!);
      _todaySessions = await _sessionDao.getByWorkDay(_today!.id!);
      _activeTask = await _taskDao.getActiveTask(_today!.id!);
      _activeSession =
          await _sessionDao.getActiveSession(_today!.id!);
    } else {
      _todayTasks = [];
      _todaySessions = [];
      _activeTask = null;
      _activeSession = null;
    }
    notifyListeners();
  }

  // Create work day if needed, then start a session
  Future<void> clockIn({
    String? photoPath,
    String? location,
    int? jobId,
  }) async {
    final now = DateTime.now();

    // Create work day for today if it doesn't exist
    if (_today == null) {
      final day = WorkDay(
        date: now,
        jobId: jobId,
        clockInTime: now,
        clockInPhoto: photoPath,
        clockInLocation: location,
      );
      final id = await _workDayDao.insert(day);
      _today = day.copyWith(id: id);
    }

    // Start a new session
    final session = Session(
      workDayId: _today!.id!,
      clockInTime: now,
      clockInPhoto: photoPath,
      clockInLocation: location,
    );
    final sessionId = await _sessionDao.insert(session);
    _activeSession = session.copyWith(id: sessionId);
    _todaySessions = await _sessionDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }

  Future<void> clockOut({
    String? photoPath,
    String? location,
  }) async {
    if (_activeSession == null) return;
    final now = DateTime.now();
    final raw = now.difference(_activeSession!.clockInTime);
    final rounded = TimeUtils.roundToNearest15(raw);

    final updated = _activeSession!.copyWith(
      clockOutTime: now,
      clockOutPhoto: photoPath,
      clockOutLocation: location,
      durationMinutes: rounded.inMinutes,
    );
    await _sessionDao.update(updated);
    _activeSession = null;
    _todaySessions = await _sessionDao.getByWorkDay(_today!.id!);

    // Update work day totals
    await _updateWorkDayTotals();
    notifyListeners();
  }

  // Undo the last clock-out — restores the most recent session to active
  Future<void> undoClockOut() async {
    if (_today == null) return;
    final completed =
        _todaySessions.where((s) => !s.isActive).toList();
    if (completed.isEmpty) return;

    // Get the most recent completed session
    completed.sort(
        (a, b) => b.clockInTime.compareTo(a.clockInTime));
    final last = completed.first;

    // Restore it to active (remove clock out)
    final restored = Session(
      id: last.id,
      workDayId: last.workDayId,
      clockInTime: last.clockInTime,
      clockInPhoto: last.clockInPhoto,
      clockInLocation: last.clockInLocation,
      durationMinutes: 0,
    );
    await _sessionDao.update(restored);
    _activeSession = restored;
    _todaySessions = await _sessionDao.getByWorkDay(_today!.id!);
    await _updateWorkDayTotals();
    notifyListeners();
  }

  // Delete today entirely (undo clock-in when no sessions completed)
  Future<void> resetDay() async {
    if (_today == null) return;
    for (final task in _todayTasks) {
      if (task.id != null) await _taskDao.delete(task.id!);
    }
    await _sessionDao.deleteByWorkDay(_today!.id!);
    final db = await DatabaseHelper.instance.database;
    await db.delete('work_days',
        where: 'id = ?', whereArgs: [_today!.id]);
    _today = null;
    _todayTasks = [];
    _todaySessions = [];
    _activeTask = null;
    _activeSession = null;
    notifyListeners();
  }

  // Delete just the active (uncompleted) session
  Future<void> cancelActiveSession() async {
    if (_activeSession?.id == null) return;
    await _sessionDao.delete(_activeSession!.id!);
    _activeSession = null;
    _todaySessions = await _sessionDao.getByWorkDay(_today!.id!);

    // If no sessions and no tasks left, clean up the day too
    if (_todaySessions.isEmpty && _todayTasks.isEmpty) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('work_days',
          where: 'id = ?', whereArgs: [_today!.id]);
      _today = null;
    }
    notifyListeners();
  }

  Future<void> _updateWorkDayTotals() async {
    if (_today == null) return;
    final completedMinutes = _todaySessions
        .where((s) => !s.isActive)
        .fold(0, (sum, s) => sum + s.durationMinutes);

    final updated = _today!.copyWith(
      totalMinutesRaw: completedMinutes,
      totalMinutesRounded: completedMinutes,
    );
    await _workDayDao.update(updated);
    _today = updated;
  }

  Future<Task> startTask({
    String? photoPath,
    String? location,
  }) async {
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

  Future<void> editSessionTime({
    required Session session,
    DateTime? newClockIn,
    DateTime? newClockOut,
  }) async {
    final updatedClockIn = newClockIn ?? session.clockInTime;
    final updatedClockOut = newClockOut ?? session.clockOutTime;

    int newDuration = session.durationMinutes;
    if (updatedClockOut != null) {
      final raw = updatedClockOut.difference(updatedClockIn);
      final rounded = TimeUtils.roundToNearest15(raw);
      newDuration = rounded.inMinutes;
    }

    final updated = Session(
      id: session.id,
      workDayId: session.workDayId,
      clockInTime: updatedClockIn,
      clockInPhoto: session.clockInPhoto,
      clockInLocation: session.clockInLocation,
      clockOutTime: updatedClockOut,
      clockOutPhoto: session.clockOutPhoto,
      clockOutLocation: session.clockOutLocation,
      durationMinutes: newDuration,
    );

    await _sessionDao.update(updated);
    _todaySessions =
        await _sessionDao.getByWorkDay(_today!.id!);

    // Recalculate active session reference if needed
    if (_activeSession?.id == session.id) {
      _activeSession = updated;
    }

    await _updateWorkDayTotals();
    notifyListeners();
  }
}