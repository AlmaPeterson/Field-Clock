class Task {
  final int? id;
  final int workDayId;
  final String name;
  final String? division;
  final String? notes;
  final DateTime startTime;
  final String? startLocation;
  final double hourlyRate;

  Task({
    this.id,
    required this.workDayId,
    required this.name,
    this.division,
    this.notes,
    required this.startTime,
    this.startLocation,
    this.hourlyRate = 0.0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'work_day_id': workDayId,
    'name': name,
    'division': division,
    'notes': notes,
    'start_time': startTime.toIso8601String(),
    'start_location': startLocation,
    'hourly_rate': hourlyRate,
  };

  factory Task.fromMap(Map<String, dynamic> map) =>
      Task(
        id: map['id'],
        workDayId: map['work_day_id'],
        name: map['name'] ?? 'Unnamed Task',
        division: map['division'],
        notes: map['notes'],
        startTime:
            DateTime.parse(map['start_time']),
        startLocation: map['start_location'],
        hourlyRate: map['hourly_rate'] ?? 0.0,
      );

  Task copyWith({
    int? id,
    String? name,
    String? division,
    String? notes,
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
        startLocation:
            startLocation ?? this.startLocation,
        hourlyRate: hourlyRate ?? this.hourlyRate,
      );
}