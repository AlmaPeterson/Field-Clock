class TaskSession {
  final int? id;
  final int taskId;
  final DateTime startTime;
  final String? startPhoto;
  final DateTime? endTime;
  final String? endPhoto;
  final int durationMinutesRaw;
  final int durationMinutesRounded;

  TaskSession({
    this.id,
    required this.taskId,
    required this.startTime,
    this.startPhoto,
    this.endTime,
    this.endPhoto,
    this.durationMinutesRaw = 0,
    this.durationMinutesRounded = 0,
  });

  bool get isActive => endTime == null;
  Duration get durationRaw =>
      Duration(minutes: durationMinutesRaw);
  Duration get durationRounded =>
      Duration(minutes: durationMinutesRounded);

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'start_time': startTime.toIso8601String(),
    'start_photo': startPhoto,
    'end_time': endTime?.toIso8601String(),
    'end_photo': endPhoto,
    'duration_minutes_raw': durationMinutesRaw,
    'duration_minutes_rounded': durationMinutesRounded,
  };

  factory TaskSession.fromMap(
          Map<String, dynamic> map) =>
      TaskSession(
        id: map['id'],
        taskId: map['task_id'],
        startTime:
            DateTime.parse(map['start_time']),
        startPhoto: map['start_photo'],
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'])
            : null,
        endPhoto: map['end_photo'],
        durationMinutesRaw:
            map['duration_minutes_raw'] ?? 0,
        durationMinutesRounded:
            map['duration_minutes_rounded'] ?? 0,
      );

  TaskSession copyWith({
    int? id,
    DateTime? endTime,
    String? endPhoto,
    int? durationMinutesRaw,
    int? durationMinutesRounded,
    String? startPhoto,
  }) =>
      TaskSession(
        id: id ?? this.id,
        taskId: taskId,
        startTime: startTime,
        startPhoto: startPhoto ?? this.startPhoto,
        endTime: endTime ?? this.endTime,
        endPhoto: endPhoto ?? this.endPhoto,
        durationMinutesRaw:
            durationMinutesRaw ?? this.durationMinutesRaw,
        durationMinutesRounded:
            durationMinutesRounded ??
                this.durationMinutesRounded,
      );
}