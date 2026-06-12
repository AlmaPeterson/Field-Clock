class Task {
  final int? id;
  final int workDayId;
  final String name;
  final String? division;
  final String? notes;
  final DateTime startTime;
  final String? startPhoto;
  final String? startLocation;
  final DateTime? endTime;
  final String? endPhoto;
  final String? endLocation;
  final int durationMinutesRaw;
  final int durationMinutesRounded;
  final double hourlyRate;

  Task({
    this.id,
    required this.workDayId,
    required this.name,
    this.division,
    this.notes,
    required this.startTime,
    this.startPhoto,
    this.startLocation,
    this.endTime,
    this.endPhoto,
    this.endLocation,
    this.durationMinutesRaw = 0,
    this.durationMinutesRounded = 0,
    this.hourlyRate = 0.0,
  });

  bool get isInProgress => endTime == null;
  bool get isComplete => endTime != null;

  Duration get durationRaw => Duration(minutes: durationMinutesRaw);
  Duration get durationRounded =>
      Duration(minutes: durationMinutesRounded);
  double get earnings =>
      (durationMinutesRounded / 60) * hourlyRate;

  Map<String, dynamic> toMap() => {
    'id': id,
    'work_day_id': workDayId,
    'name': name,
    'division': division,
    'notes': notes,
    'start_time': startTime.toIso8601String(),
    'start_photo': startPhoto,
    'start_location': startLocation,
    'end_time': endTime?.toIso8601String(),
    'end_photo': endPhoto,
    'end_location': endLocation,
    'duration_minutes_raw': durationMinutesRaw,
    'duration_minutes_rounded': durationMinutesRounded,
    'hourly_rate': hourlyRate,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
      id: map['id'],
      workDayId: map['work_day_id'],
      name: map['name'] ?? 'Unnamed Task',
      division: map['division'],
      notes: map['notes'],
      startTime: DateTime.parse(map['start_time']),
      startPhoto: map['start_photo'],
      startLocation: map['start_location'],
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'])
          : null,
      endPhoto: map['end_photo'],
      endLocation: map['end_location'],
      durationMinutesRaw: map['duration_minutes_raw'] ?? 0,
      durationMinutesRounded:
          map['duration_minutes_rounded'] ?? 0,
      hourlyRate: map['hourly_rate'] ?? 0.0,
    );

    Task copyWith({
      int? id,
      String? name,
      String? division,
      String? notes,
      DateTime? endTime,
      String? endPhoto,
      String? endLocation,
      int? durationMinutesRaw,
      int? durationMinutesRounded,
      String? startPhoto,
      String? startLocation,
      double? hourlyRate,
    }) =>
        Task(
          id: id ?? this.id,
          workDayId: workDayId,
          name: name ?? this.name,
          division: division ?? this.division,
          notes: notes ?? this.notes,
          startTime: startTime,
          startPhoto: startPhoto ?? this.startPhoto,
          startLocation: startLocation ?? this.startLocation,
          endTime: endTime ?? this.endTime,
          endPhoto: endPhoto ?? this.endPhoto,
          endLocation: endLocation ?? this.endLocation,
          durationMinutesRaw:
              durationMinutesRaw ?? this.durationMinutesRaw,
          durationMinutesRounded:
              durationMinutesRounded ?? this.durationMinutesRounded,
          hourlyRate: hourlyRate ?? this.hourlyRate,
        );
}