import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import 'firebase_bootstrap.dart';

class NotificationService {
  final List<AppNotification> _localNotifications = <AppNotification>[];

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> createNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String title,
    required String message,
    required String type,
    String? classroomId,
  }) async {
    if (toUserId.trim().isEmpty || toUserId == fromUserId) {
      return;
    }

    final notification = AppNotification(
      id: '',
      toUserId: toUserId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      title: title.trim(),
      message: message.trim(),
      type: type.trim(),
      classroomId: classroomId,
      createdAt: DateTime.now(),
    );

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('notifications').doc();
      await doc.set(notification.copyWith(id: doc.id).toMap());
      return;
    }

    _localNotifications.insert(
      0,
      notification.copyWith(
        id: 'notification_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
  }

  Future<List<AppNotification>> fetchNotificationsForUser(String userId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .get();
      final notifications = snapshot.docs
          .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }

    final notifications = _localNotifications
        .where((item) => item.toUserId == userId)
        .toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<int> fetchUnreadCount(String userId) async {
    final notifications = await fetchNotificationsForUser(userId);
    return notifications.where((item) => !item.isRead).length;
  }

  Future<void> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    if (FirebaseBootstrap.isReady) {
      await _firestore.collection('notifications').doc(notificationId).update(
        <String, dynamic>{'isRead': true},
      );
      return;
    }

    final index = _localNotifications.indexWhere(
      (item) => item.id == notificationId && item.toUserId == userId,
    );
    if (index >= 0) {
      _localNotifications[index] = _localNotifications[index].copyWith(
        isRead: true,
      );
    }
  }

  Future<void> markAllAsRead(String userId) async {
    final notifications = await fetchNotificationsForUser(userId);
    for (final notification in notifications.where((item) => !item.isRead)) {
      await markAsRead(notificationId: notification.id, userId: userId);
    }
  }
}
