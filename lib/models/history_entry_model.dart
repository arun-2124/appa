class HistoryEntry {
  final String id;
  final String userId;
  final String medicineName;
  final DateTime takenAt;
  final bool successful;

  const HistoryEntry({
    required this.id,
    required this.userId,
    required this.medicineName,
    required this.takenAt,
    required this.successful,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'medicineName': medicineName,
      'takenAt': takenAt.toIso8601String(),
      'successful': successful,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      medicineName: map['medicineName']?.toString() ?? 'Unknown Medicine',
      takenAt: DateTime.tryParse(
            map['takenAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      successful: map['successful'] ?? true,
    );
  }

  HistoryEntry copyWith({
    String? id,
    String? userId,
    String? medicineName,
    DateTime? takenAt,
    bool? successful,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      medicineName: medicineName ?? this.medicineName,
      takenAt: takenAt ?? this.takenAt,
      successful: successful ?? this.successful,
    );
  }
}