import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/teacher_delegation.dart';
import 'firebase_bootstrap.dart';

class DelegationService {
  final List<TeacherDelegation> _localDelegations = <TeacherDelegation>[];

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String buildDelegationId({
    required String ownerTeacherId,
    required String delegateTeacherId,
    required String classroomId,
  }) {
    return '${ownerTeacherId}_${delegateTeacherId}_$classroomId';
  }

  Future<TeacherDelegation> upsertTeacherDelegation({
    required String ownerTeacherId,
    required String ownerTeacherName,
    required String delegateTeacherId,
    required String delegateTeacherName,
    required String classroomId,
    required String classroomSection,
    required String hodId,
    required String reason,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    if (ownerTeacherId.trim().isEmpty || delegateTeacherId.trim().isEmpty) {
      throw DelegationException('Invalid owner/delegate teacher id.');
    }
    if (ownerTeacherId == delegateTeacherId) {
      throw DelegationException('Owner and delegate cannot be the same teacher.');
    }
    if (!endAt.isAfter(startAt)) {
      throw DelegationException('Delegation end time must be after start time.');
    }
    if (classroomId.trim().isEmpty) {
      throw DelegationException('Classroom id is required for delegation.');
    }

    final now = DateTime.now();
    final delegation = TeacherDelegation(
      id: buildDelegationId(
        ownerTeacherId: ownerTeacherId,
        delegateTeacherId: delegateTeacherId,
        classroomId: classroomId,
      ),
      ownerTeacherId: ownerTeacherId,
      ownerTeacherName: ownerTeacherName,
      delegateTeacherId: delegateTeacherId,
      delegateTeacherName: delegateTeacherName,
      classroomId: classroomId,
      classroomSection: classroomSection,
      hodId: hodId,
      reason: reason.trim().isEmpty ? 'Delegation enabled by HOD' : reason.trim(),
      startAt: startAt,
      endAt: endAt,
      isActive: true,
      createdAt: now,
    );

    if (FirebaseBootstrap.isReady) {
      await _firestore
          .collection('teacher_delegations')
          .doc(delegation.id)
          .set(delegation.toMap());
      return delegation;
    }

    _localDelegations.removeWhere((item) => item.id == delegation.id);
    _localDelegations.insert(0, delegation);
    return delegation;
  }

  Future<TeacherDelegation?> findActiveTeacherDelegation({
    required String ownerTeacherId,
    required String delegateTeacherId,
    required String classroomId,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();

    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('teacher_delegations')
          .where('ownerTeacherId', isEqualTo: ownerTeacherId)
          .get();
      final delegations = snapshot.docs
          .map((doc) => TeacherDelegation.fromMap(doc.data(), doc.id))
          .where((item) => item.delegateTeacherId == delegateTeacherId)
          .where((item) => item.classroomId == classroomId)
          .where((item) => item.isActive)
          .where((item) => !now.isBefore(item.startAt) && !now.isAfter(item.endAt))
          .toList();
      if (delegations.isEmpty) {
        return null;
      }
      delegations.sort((a, b) => b.startAt.compareTo(a.startAt));
      return delegations.first;
    }

    final delegations = _localDelegations
        .where((item) => item.ownerTeacherId == ownerTeacherId)
        .where((item) => item.delegateTeacherId == delegateTeacherId)
        .where((item) => item.classroomId == classroomId)
        .where((item) => item.isActive)
        .where((item) => !now.isBefore(item.startAt) && !now.isAfter(item.endAt))
        .toList();
    if (delegations.isEmpty) {
      return null;
    }
    delegations.sort((a, b) => b.startAt.compareTo(a.startAt));
    return delegations.first;
  }

  Future<List<TeacherDelegation>> fetchActiveDelegationsForDelegate(
    String delegateTeacherId, {
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();

    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('teacher_delegations')
          .where('delegateTeacherId', isEqualTo: delegateTeacherId)
          .get();
      return snapshot.docs
          .map((doc) => TeacherDelegation.fromMap(doc.data(), doc.id))
          .where((item) => item.isActive)
          .where((item) => !now.isBefore(item.startAt) && !now.isAfter(item.endAt))
          .toList();
    }

    return _localDelegations
        .where((item) => item.delegateTeacherId == delegateTeacherId)
        .where((item) => item.isActive)
        .where((item) => !now.isBefore(item.startAt) && !now.isAfter(item.endAt))
        .toList();
  }
}

class DelegationException implements Exception {
  DelegationException(this.message);

  final String message;

  @override
  String toString() => message;
}
