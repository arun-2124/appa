class AppUser {
  final String uid;
  final String email;
  final String name;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'],
    email: map['email'],
    name: map['name'],
    createdAt: DateTime.parse(map['createdAt']),
  );
}