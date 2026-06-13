class Prescription {
  final String id;
  final String userId;
  final String doctorName;
  final String medicineName;
  final String fileUrl;
  final DateTime uploadedAt;

  Prescription({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.medicineName,
    required this.fileUrl,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'doctorName': doctorName,
    'medicineName': medicineName,
    'fileUrl': fileUrl,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory Prescription.fromMap(Map<String, dynamic> map) => Prescription(
    id: map['id'],
    userId: map['userId'],
    doctorName: map['doctorName'],
    medicineName: map['medicineName'],
    fileUrl: map['fileUrl'],
    uploadedAt: DateTime.parse(map['uploadedAt']),
  );
}