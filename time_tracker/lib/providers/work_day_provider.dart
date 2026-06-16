import 'package:flutter/foundation.dart';
import '../models/work_day.dart';
import '../models/task.dart';
import '../models/task_session.dart';
import '../models/session.dart';
import '../database/dao/work_day_dao.dart';
import '../database/dao/task_dao.dart';
import '../database/dao/task_session_dao.dart';
import '../database/dao/session_dao.dart';
import '../database/database_helper.dart';
import '../utils/time_utils.dart';

class WorkDayProvider extends ChangeNotifier {
  final WorkDayDao _workDayDao = WorkDayDao();
  final TaskDao _taskDao = TaskDao();
  final TaskSessionDao _taskSessionDao =
      TaskSessionDao();
  final SessionDao _sessionDao = SessionDao();

  WorkDay? _today;
  List<Task> _todayTasks = [];
  List<Session> _todaySessions = [];
  Task? _activeTask;
  TaskSession? _activeTaskSession;
  Session? _activeSession;

  WorkDay? get today => _today;
  List<Task> get todayTasks => _todayTasks;
  List<Session> get todaySessions => _todaySessions;
  Task? get activeTask => _activeTask;
  TaskSession? get activeTaskSession =>
      _activeTaskSession;
  Session? get activeSession => _activeSession;

  bool get isClockedIn => _activeSession != null;
  bool get hasClockedInToday => _today != null;
  bool get hasActiveTask => _activeTask != null;
  bool get hasActiveTaskSession =>
      _activeTaskSession != null;

  int get totalSessionMinutes => _todaySessions
      .where((s) => !s.isActive)
      .fold(0, (sum, s) => sum + s.durationMinutes);

  Future<void> loadToday() async {
    _today = await _workDayDao.getToday();
    if (_today != null) {
      _todayTasks =
          await _taskDao.getByWorkDay(_today!.id!);
      _todaySessions =
          await _sessionDao.getByWorkDay(_today!.id!);
      _activeSession =
          await _sessionDao.getActiveSession(_today!.id!);

      // Find active task (one with an active session)
      _activeTask = null;
      _activeTaskSession = null;
      for (final task in _todayTasks) {
        final active = await _taskSessionDao
            .getActiveSession(task.id!);
        if (active != null) {
          _activeTask = task;
          _activeTaskSession = active;
          break;
        }
      }
    } else {
      _todayTasks = [];
      _todaySessions = [];
      _activeTask = null;
      _activeTaskSession = null;
      _activeSession = null;
    }
    notifyListeners();
  }

  // ── Clock in / out ───────────────────────────────

  Future<void> clockIn({
    String? photoPath,
    String? location,
    int? jobId,
  }) async {
    final now = DateTime.now();
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
    final session = Session(
      workDayId: _today!.id!,
      clockInTime: now,
      clockInPhoto: photoPath,
      clockInLocation: location,
    );
    final sessionId =
        await _sessionDao.insert(session);
    _activeSession = session.copyWith(id: sessionId);
    _todaySessions =
        await _sessionDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }

  Future<void> clockOut({
    String? photoPath,
    String? location,
  }) async {
    if (_activeSession == null) return;
    final now = DateTime.now();
    final raw =
        now.difference(_activeSession!.clockInTime);
    final rounded = TimeUtils.roundToNearest15(raw);
    final updated = _activeSession!.copyWith(
      clockOutTime: now,
      clockOutPhoto: photoPath,
      clockOutLocation: location,
      durationMinutes: rounded.inMinutes,
    );
    await _sessionDao.update(updated);
    _activeSession = null;
    _todaySessions =
        await _sessionDao.getByWorkDay(_today!.id!);
    await _updateWorkDayTotals();
    notifyListeners();
  }

  Future<void> undoClockOut() async {
    if (_today == null) return;
    final completed = _todaySessions
        .where((s) => !s.isActive)
        .toList()
      ..sort((a, b) =>
          b.clockInTime.compareTo(a.clockInTime));
    if (completed.isEmpty) return;
    final last = completed.first;
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
    _todaySessions =
        await _sessionDao.getByWorkDay(_today!.id!);
    await _updateWorkDayTotals();
    notifyListeners();
  }

  Future<void> cancelActiveSession() async {
    if (_activeSession?.id == null) return;
    await _sessionDao.delete(_activeSession!.id!);
    _activeSession = null;
    _todaySessions =
        await _sessionDao.getByWorkDay(_today!.id!);
    if (_todaySessions.isEmpty &&
        _todayTasks.isEmpty) {
      final db =
          await DatabaseHelper.instance.database;
      await db.delete('work_days',
          where: 'id = ?',
          whereArgs: [_today!.id]);
      _today = null;
    }
    notifyListeners();
  }

  Future<void> resetDay() async {
    if (_today == null) return;
    await DatabaseHelper.instance
        .deleteDayCascade(_today!.id!);
    _today = null;
    _todayTasks = [];
    _todaySessions = [];
    _activeTask = null;
    _activeTaskSession = null;
    _activeSession = null;
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

  Future<void> editSessionTime({
    required Session session,
    DateTime? newClockIn,
    DateTime? newClockOut,
  }) async {
    final updatedClockIn =
        newClockIn ?? session.clockInTime;
    final updatedClockOut =
        newClockOut ?? session.clockOutTime;
    int newDuration = session.durationMinutes;
    if (updatedClockOut != null) {
      final raw =
          updatedClockOut.difference(updatedClockIn);
      newDuration =
          TimeUtils.roundToNearest15(raw).inMinutes;
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
    if (_activeSession?.id == session.id) {
      _activeSession = updated;
    }
    await _updateWorkDayTotals();
    notifyListeners();
  }

  // ── Task management ──────────────────────────────

  /// Start a new task with its first session
  Future<Task> startTask({
    String? photoPath,
    String? location,
  }) async {
    if (_today == null) throw Exception('Not clocked in');
    final now = DateTime.now();

    // Create the task container
    final task = Task(
      workDayId: _today!.id!,
      name: 'Unnamed Task',
      startTime: now,
      startLocation: location,
    );
    final taskId = await _taskDao.insert(task);
    final savedTask = task.copyWith(id: taskId);

    // Create first task session
    final taskSession = TaskSession(
      taskId: taskId,
      startTime: now,
      startPhoto: photoPath,
    );
    final tsId =
        await _taskSessionDao.insert(taskSession);

    _activeTask = savedTask;
    _activeTaskSession =
        taskSession.copyWith(id: tsId);
    _todayTasks =
        await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
    return savedTask;
  }

  /// End the active task session and name the task
  Future<void> endTask({
    required String name,
    String? division,
    String? photoPath,
    String? location,
    String? notes,
    double hourlyRate = 0.0,
  }) async {
    if (_activeTask == null ||
        _activeTaskSession == null) return;
    final now = DateTime.now();
    final raw =
        now.difference(_activeTaskSession!.startTime);
    final rounded = TimeUtils.roundToNearest15(raw);

    // End the task session
    final updatedSession =
        _activeTaskSession!.copyWith(
      endTime: now,
      endPhoto: photoPath,
      durationMinutesRaw: raw.inMinutes,
      durationMinutesRounded: rounded.inMinutes,
    );
    await _taskSessionDao.update(updatedSession);

    // Update task metadata
    final updatedTask = _activeTask!.copyWith(
      name: name,
      division: division,
      notes: notes,
      hourlyRate: hourlyRate,
    );
    await _taskDao.update(updatedTask);

    _activeTask = null;
    _activeTaskSession = null;
    _todayTasks =
        await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }

  /// Resume a task — add another session to it
  Future<void> resumeTask({
    required Task task,
    String? photoPath,
  }) async {
    final now = DateTime.now();
    final taskSession = TaskSession(
      taskId: task.id!,
      startTime: now,
      startPhoto: photoPath,
    );
    final tsId =
        await _taskSessionDao.insert(taskSession);
    _activeTask = task;
    _activeTaskSession =
        taskSession.copyWith(id: tsId);
    _todayTasks =
        await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await _taskDao.update(task);
    _todayTasks =
        await _taskDao.getByWorkDay(_today!.id!);
    notifyListeners();
  }
}