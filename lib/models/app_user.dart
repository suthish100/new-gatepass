class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.year,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String? year;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'year': year,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? '',
      department: map['department'] as String? ?? '',
      year: map['year'] as String?,
    );
  }
}
