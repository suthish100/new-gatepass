import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.toUserId,
    required this.fromUserId,
    required this.fromUserName,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.classroomId,
    this.isRead = false,
  });

  final String id;
  final String toUserId;
  final String fromUserId;
  final String fromUserName;
  final String title;
  final String message;
  final String type;
  final DateTime createdAt;
  final String? classroomId;
  final bool isRead;

  AppNotification copyWith({
    String? id,
    String? toUserId,
    String? fromUserId,
    String? fromUserName,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    String? classroomId,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      toUserId: toUserId ?? this.toUserId,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      classroomId: classroomId ?? this.classroomId,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'toUserId': toUserId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'classroomId': classroomId,
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return AppNotification(
      id: id,
      toUserId: map['toUserId'] as String? ?? '',
      fromUserId: map['fromUserId'] as String? ?? '',
      fromUserName: map['fromUserName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: map['type'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      classroomId: map['classroomId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
