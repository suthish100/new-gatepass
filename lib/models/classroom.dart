import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  const Classroom({
    required this.id,
    required this.section,
    required this.year,
    required this.department,
    required this.hodId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.staffCode,
    required this.studentCode,
    required this.code,
    required this.inviteLink,
    required this.createdAt,
  });

  final String id;
  final String section;
  final String year;
  final String department;
  final String hodId;
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String staffCode;
  final String studentCode;
  final String code;
  final String inviteLink;
  final DateTime createdAt;

  Classroom copyWith({
    String? id,
    String? section,
    String? year,
    String? department,
    String? hodId,
    String? teacherId,
    String? teacherName,
    String? teacherEmail,
    String? staffCode,
    String? studentCode,
    String? code,
    String? inviteLink,
    DateTime? createdAt,
  }) {
    return Classroom(
      id: id ?? this.id,
      section: section ?? this.section,
      year: year ?? this.year,
      department: department ?? this.department,
      hodId: hodId ?? this.hodId,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      staffCode: staffCode ?? this.staffCode,
      studentCode: studentCode ?? this.studentCode,
      code: code ?? this.code,
      inviteLink: inviteLink ?? this.inviteLink,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'section': section,
      'year': year,
      'department': department,
      'hodId': hodId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
      'staffCode': staffCode,
      'studentCode': studentCode,
      'code': code,
      'inviteLink': inviteLink,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map, String id) {
    final created = map['createdAt'];
    DateTime createdAt;
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created is DateTime) {
      createdAt = created;
    } else {
      createdAt = DateTime.now();
    }

    final year = map['year'] as String? ?? '';
    final department = map['department'] as String? ?? '';
    final section = map['section'] as String? ?? '';
    final studentCode =
        map['studentCode'] as String? ?? map['code'] as String? ?? '';

    return Classroom(
      id: id,
      section: section.isNotEmpty
          ? section
          : '${year.isEmpty ? 'Class' : year} - ${department.isEmpty ? 'Department' : department}',
      year: year,
      department: department,
      hodId: map['hodId'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      teacherEmail: map['teacherEmail'] as String? ?? '',
      staffCode: map['staffCode'] as String? ?? '',
      studentCode: studentCode,
      code: map['code'] as String? ?? studentCode,
      inviteLink: map['inviteLink'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}
