class Job {
  final int? id;
  final String name;
  final String? address;
  final String? clientName;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'active' | 'completed' | 'paused'

  Job({
    this.id,
    required this.name,
    this.address,
    this.clientName,
    required this.startDate,
    this.endDate,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'client_name': clientName,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'status': status,
  };

  factory Job.fromMap(Map<String, dynamic> map) => Job(
    id: map['id'],
    name: map['name'],
    address: map['address'],
    clientName: map['client_name'],
    startDate: DateTime.parse(map['start_date']),
    endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
    status: map['status'] ?? 'active',
  );

  Job copyWith({
    int? id, String? name, String? address,
    String? clientName, DateTime? endDate, String? status,
  }) => Job(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    clientName: clientName ?? this.clientName,
    startDate: startDate,
    endDate: endDate ?? this.endDate,
    status: status ?? this.status,
  );
}