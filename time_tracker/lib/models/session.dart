class Session {
  final int? id;
  final int workDayId;
  final DateTime clockInTime;
  final String? clockInPhoto;
  final String? clockInLocation;
  final DateTime? clockOutTime;
  final String? clockOutPhoto;
  final String? clockOutLocation;
  final int durationMinutes;

  Session({
    this.id,
    required this.workDayId,
    required this.clockInTime,
    this.clockInPhoto,
    this.clockInLocation,
    this.clockOutTime,
    this.clockOutPhoto,
    this.clockOutLocation,
    this.durationMinutes = 0,
  });

  bool get isActive => clockOutTime == null;
  Duration get duration => Duration(minutes: durationMinutes);

  Map<String, dynamic> toMap() => {
    'id': id,
    'work_day_id': workDayId,
    'clock_in_time': clockInTime.toIso8601String(),
    'clock_in_photo': clockInPhoto,
    'clock_in_location': clockInLocation,
    'clock_out_time': clockOutTime?.toIso8601String(),
    'clock_out_photo': clockOutPhoto,
    'clock_out_location': clockOutLocation,
    'duration_minutes': durationMinutes,
  };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'],
    workDayId: map['work_day_id'],
    clockInTime: DateTime.parse(map['clock_in_time']),
    clockInPhoto: map['clock_in_photo'],
    clockInLocation: map['clock_in_location'],
    clockOutTime: map['clock_out_time'] != null
        ? DateTime.parse(map['clock_out_time'])
        : null,
    clockOutPhoto: map['clock_out_photo'],
    clockOutLocation: map['clock_out_location'],
    durationMinutes: map['duration_minutes'] ?? 0,
  );

  Session copyWith({
    int? id,
    DateTime? clockOutTime,
    String? clockOutPhoto,
    String? clockOutLocation,
    int? durationMinutes,
  }) =>
      Session(
        id: id ?? this.id,
        workDayId: workDayId,
        clockInTime: clockInTime,
        clockInPhoto: clockInPhoto,
        clockInLocation: clockInLocation,
        clockOutTime: clockOutTime ?? this.clockOutTime,
        clockOutPhoto: clockOutPhoto ?? this.clockOutPhoto,
        clockOutLocation: clockOutLocation ?? this.clockOutLocation,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );
}