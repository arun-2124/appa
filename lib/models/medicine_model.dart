class Medicine {
  final String id;
  final String userId;
  final String name;
  final String dose;
  final String time;
  final bool taken;
  final DateTime createdAt;

  Medicine({
    required this.id,
    required this.userId,
    required this.name,
    required this.dose,
    required this.time,
    this.taken = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'dose': dose,
      'time': time,
      'taken': taken,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      dose: map['dose'] ?? '',
      time: map['time'] ?? '',
      taken: map['taken'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}