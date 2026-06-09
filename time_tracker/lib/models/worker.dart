class Worker {
  final int? id;
  final String name;
  final double hourlyRate;
  final DateTime createdAt;

  Worker({
    this.id,
    required this.name,
    this.hourlyRate = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'hourly_rate': hourlyRate,
    'created_at': createdAt.toIso8601String(),
  };

  factory Worker.fromMap(Map<String, dynamic> map) => Worker(
    id: map['id'],
    name: map['name'],
    hourlyRate: map['hourly_rate'] ?? 0.0,
    createdAt: DateTime.parse(map['created_at']),
  );

  Worker copyWith({int? id, String? name, double? hourlyRate}) => Worker(
    id: id ?? this.id,
    name: name ?? this.name,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    createdAt: createdAt,
  );
}