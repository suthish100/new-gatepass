import 'package:cloud_firestore/cloud_firestore.dart';

class Classroom {
  const Classroom({
    required this.id,
    required this.section,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.code,
    required this.inviteLink,
    required this.createdAt,
  });

  final String id;
  final String section;
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String code;
  final String inviteLink;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'section': section,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
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

    return Classroom(
      id: id,
      section: map['section'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      teacherEmail: map['teacherEmail'] as String? ?? '',
      code: map['code'] as String? ?? '',
      inviteLink: map['inviteLink'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}
