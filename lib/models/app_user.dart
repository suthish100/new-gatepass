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
    this.roomNumber,
    this.gender,
    this.phoneNumber,
    this.parentPhoneNumber,
    this.profileImageBase64,
    this.themeMode,
    this.orgId,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String? year;
  final String? hodType;
  final String? registerNumber;
  final String? roomNumber;
  final String? gender;
  final String? phoneNumber;
  final String? parentPhoneNumber;
  final String? profileImageBase64;
  final String? themeMode;
  final String? orgId;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? department,
    String? year,
    String? hodType,
    String? registerNumber,
    String? roomNumber,
    String? gender,
    String? phoneNumber,
    String? parentPhoneNumber,
    String? profileImageBase64,
    String? themeMode,
    String? orgId,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      year: year ?? this.year,
      hodType: hodType ?? this.hodType,
      registerNumber: registerNumber ?? this.registerNumber,
      roomNumber: roomNumber ?? this.roomNumber,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      parentPhoneNumber: parentPhoneNumber ?? this.parentPhoneNumber,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      themeMode: themeMode ?? this.themeMode,
      orgId: orgId ?? this.orgId,
    );
  }

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
      'roomNumber': roomNumber,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'parentPhoneNumber': parentPhoneNumber,
      'profileImageBase64': profileImageBase64,
      'themeMode': themeMode,
      'orgId': orgId,
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
      roomNumber:
          map['roomNumber'] as String? ?? map['registerNumber'] as String?,
      gender: map['gender'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      parentPhoneNumber: map['parentPhoneNumber'] as String?,
      profileImageBase64: map['profileImageBase64'] as String?,
      themeMode: map['themeMode'] as String?,
      orgId: map['orgId'] as String?,
    );
  }
}
