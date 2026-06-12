class WorkDay {
  final int? id;
  final int? jobId;
  final DateTime date;
  final DateTime? clockInTime;
  final String? clockInPhoto;
  final String? clockInLocation;
  final DateTime? clockOutTime;
  final String? clockOutPhoto;
  final String? clockOutLocation;
  final int totalMinutesRaw;
  final int totalMinutesRounded;

  WorkDay({
    this.id,
    this.jobId,
    required this.date,
    this.clockInTime,
    this.clockInPhoto,
    this.clockInLocation,
    this.clockOutTime,
    this.clockOutPhoto,
    this.clockOutLocation,
    this.totalMinutesRaw = 0,
    this.totalMinutesRounded = 0,
  });

  bool get isClockedIn =>
      clockInTime != null && clockOutTime == null;
  bool get isComplete =>
      clockInTime != null && clockOutTime != null;

  Duration get totalDurationRaw =>
      Duration(minutes: totalMinutesRaw);
  Duration get totalDurationRounded =>
      Duration(minutes: totalMinutesRounded);

  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'date': date.toIso8601String(),
    'clock_in_time': clockInTime?.toIso8601String(),
    'clock_in_photo': clockInPhoto,
    'clock_in_location': clockInLocation,
    'clock_out_time': clockOutTime?.toIso8601String(),
    'clock_out_photo': clockOutPhoto,
    'clock_out_location': clockOutLocation,
    'total_minutes_raw': totalMinutesRaw,
    'total_minutes_rounded': totalMinutesRounded,
  };

  factory WorkDay.fromMap(Map<String, dynamic> map) =>
      WorkDay(
        id: map['id'],
        jobId: map['job_id'],
        date: DateTime.parse(map['date']),
        clockInTime: map['clock_in_time'] != null
            ? DateTime.parse(map['clock_in_time'])
            : null,
        clockInPhoto: map['clock_in_photo'],
        clockInLocation: map['clock_in_location'],
        clockOutTime: map['clock_out_time'] != null
            ? DateTime.parse(map['clock_out_time'])
            : null,
        clockOutPhoto: map['clock_out_photo'],
        clockOutLocation: map['clock_out_location'],
        totalMinutesRaw: map['total_minutes_raw'] ?? 0,
        totalMinutesRounded:
            map['total_minutes_rounded'] ?? 0,
      );

  WorkDay copyWith({
    int? id,
    int? jobId,
    DateTime? clockInTime,
    String? clockInPhoto,
    String? clockInLocation,
    DateTime? clockOutTime,
    String? clockOutPhoto,
    String? clockOutLocation,
    int? totalMinutesRaw,
    int? totalMinutesRounded,
  }) =>
      WorkDay(
        id: id ?? this.id,
        jobId: jobId ?? this.jobId,
        date: date,
        clockInTime: clockInTime ?? this.clockInTime,
        clockInPhoto: clockInPhoto ?? this.clockInPhoto,
        clockInLocation:
            clockInLocation ?? this.clockInLocation,
        clockOutTime: clockOutTime ?? this.clockOutTime,
        clockOutPhoto: clockOutPhoto ?? this.clockOutPhoto,
        clockOutLocation:
            clockOutLocation ?? this.clockOutLocation,
        totalMinutesRaw:
            totalMinutesRaw ?? this.totalMinutesRaw,
        totalMinutesRounded:
            totalMinutesRounded ?? this.totalMinutesRounded,
      );
}