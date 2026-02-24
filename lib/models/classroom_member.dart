import 'package:cloud_firestore/cloud_firestore.dart';

class ClassroomMember {
  const ClassroomMember({
    required this.id,
    required this.classroomId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.joinedAt,
  });

  final String id;
  final String classroomId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime joinedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'classroomId': classroomId,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  factory ClassroomMember.fromMap(Map<String, dynamic> map, String id) {
    final joined = map['joinedAt'];
    DateTime joinedAt;
    if (joined is Timestamp) {
      joinedAt = joined.toDate();
    } else if (joined is DateTime) {
      joinedAt = joined;
    } else {
      joinedAt = DateTime.now();
    }

    return ClassroomMember(
      id: id,
      classroomId: map['classroomId'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentEmail: map['studentEmail'] as String? ?? '',
      joinedAt: joinedAt,
    );
  }
}
