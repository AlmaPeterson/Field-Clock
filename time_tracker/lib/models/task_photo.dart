class TaskPhoto {
  final int? id;
  final int taskId;
  final String photoPath;
  final String photoType; // 'before' | 'after' | 'general'
  final DateTime createdAt;

  TaskPhoto({
    this.id,
    required this.taskId,
    required this.photoPath,
    this.photoType = 'general',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'task_id': taskId,
    'photo_path': photoPath,
    'photo_type': photoType,
    'created_at': createdAt.toIso8601String(),
  };

  factory TaskPhoto.fromMap(Map<String, dynamic> map) => TaskPhoto(
    id: map['id'],
    taskId: map['task_id'],
    photoPath: map['photo_path'],
    photoType: map['photo_type'] ?? 'general',
    createdAt: DateTime.parse(map['created_at']),
  );

  TaskPhoto copyWith({int? id, String? photoType}) => TaskPhoto(
    id: id ?? this.id,
    taskId: taskId,
    photoPath: photoPath,
    photoType: photoType ?? this.photoType,
    createdAt: createdAt,
  );
}