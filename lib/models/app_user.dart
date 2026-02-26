class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.year,
    this.hodType,
    this.registerNumber,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String? year;
  final String? hodType;
  final String? registerNumber;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'year': year,
      'hodType': hodType,
      'registerNumber': registerNumber,
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
      hodType: map['hodType'] as String?,
      registerNumber: map['registerNumber'] as String?,
    );
  }
}
