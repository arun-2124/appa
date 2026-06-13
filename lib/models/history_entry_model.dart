class HistoryEntry {
  final String id;
  final String userId;
  final String medicineName;
  final DateTime takenAt;
  final bool successful;

  HistoryEntry({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.takenAt,
    required this.successful,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'medicineName': medicineName,
    'takenAt': takenAt.toIso8601String(),
    'successful': successful,
  };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
    id: map['id'],
    userId: map['userId'],
    medicineName: map['medicineName'],
    takenAt: DateTime.parse(map['takenAt']),
    successful: map['successful'] ?? true,
  );
}