import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherDelegation {
  const TeacherDelegation({
    required this.id,
    required this.ownerTeacherId,
    required this.ownerTeacherName,
    required this.delegateTeacherId,
    required this.delegateTeacherName,
    required this.classroomId,
    required this.classroomSection,
    required this.hodId,
    required this.reason,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String ownerTeacherId;
  final String ownerTeacherName;
  final String delegateTeacherId;
  final String delegateTeacherName;
  final String classroomId;
  final String classroomSection;
  final String hodId;
  final String reason;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final DateTime createdAt;

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && !now.isBefore(startAt) && !now.isAfter(endAt);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerTeacherId': ownerTeacherId,
      'ownerTeacherName': ownerTeacherName,
      'delegateTeacherId': delegateTeacherId,
      'delegateTeacherName': delegateTeacherName,
      'classroomId': classroomId,
      'classroomSection': classroomSection,
      'hodId': hodId,
      'reason': reason,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TeacherDelegation.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return TeacherDelegation(
      id: id,
      ownerTeacherId: map['ownerTeacherId'] as String? ?? '',
      ownerTeacherName: map['ownerTeacherName'] as String? ?? '',
      delegateTeacherId: map['delegateTeacherId'] as String? ?? '',
      delegateTeacherName: map['delegateTeacherName'] as String? ?? '',
      classroomId: map['classroomId'] as String? ?? '',
      classroomSection: map['classroomSection'] as String? ?? '',
      hodId: map['hodId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      startAt: parseDate(map['startAt']),
      endAt: parseDate(map['endAt']),
      isActive: map['isActive'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
