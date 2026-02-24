import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/classroom.dart';
import '../models/classroom_member.dart';
import '../models/staff_invite.dart';
import 'firebase_bootstrap.dart';

class ClassroomService {
  final List<StaffInvite> _localInvites = <StaffInvite>[];
  final List<Classroom> _localClassrooms = <Classroom>[];
  final List<ClassroomMember> _localMembers = <ClassroomMember>[];
  final Random _random = Random();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<StaffInvite> sendStaffInvitation({
    required String hodId,
    required String section,
    required String staffEmail,
  }) async {
    final token = _randomToken(12);
    final link =
        'https://e-gatepass.app/invite?role=teacher&section=${Uri.encodeComponent(section)}&token=$token';
    final now = DateTime.now();

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('staff_invites').doc();
      final invite = StaffInvite(
        id: doc.id,
        hodId: hodId,
        section: section,
        staffEmail: staffEmail.trim().toLowerCase(),
        inviteLink: link,
        createdAt: now,
      );
      await doc.set(invite.toMap());
      return invite;
    }

    final invite = StaffInvite(
      id: 'invite_${DateTime.now().microsecondsSinceEpoch}',
      hodId: hodId,
      section: section,
      staffEmail: staffEmail.trim().toLowerCase(),
      inviteLink: link,
      createdAt: now,
    );
    _localInvites.insert(0, invite);
    return invite;
  }

  Future<List<StaffInvite>> fetchInvitesForHod(String hodId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('staff_invites')
          .where('hodId', isEqualTo: hodId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => StaffInvite.fromMap(doc.data(), doc.id))
          .toList();
    }

    return _localInvites.where((invite) => invite.hodId == hodId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Classroom> createClassroom({
    required String section,
    required AppUser teacher,
  }) async {
    final now = DateTime.now();
    final code = await _generateUniqueClassCode();
    final inviteLink = 'https://e-gatepass.app/join?code=$code';

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('classrooms').doc();
      final room = Classroom(
        id: doc.id,
        section: section,
        teacherId: teacher.id,
        teacherName: teacher.name,
        teacherEmail: teacher.email,
        code: code,
        inviteLink: inviteLink,
        createdAt: now,
      );
      await doc.set(room.toMap());
      return room;
    }

    final room = Classroom(
      id: 'class_${DateTime.now().microsecondsSinceEpoch}',
      section: section,
      teacherId: teacher.id,
      teacherName: teacher.name,
      teacherEmail: teacher.email,
      code: code,
      inviteLink: inviteLink,
      createdAt: now,
    );
    _localClassrooms.insert(0, room);
    return room;
  }

  Future<List<Classroom>> fetchClassroomsForTeacher(String teacherId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('classrooms')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => Classroom.fromMap(doc.data(), doc.id))
          .toList();
    }

    return _localClassrooms
        .where((room) => room.teacherId == teacherId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ClassroomMember>> fetchStudentsForClassroom(
    String classroomId,
  ) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('classroom_members')
          .where('classroomId', isEqualTo: classroomId)
          .orderBy('joinedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => ClassroomMember.fromMap(doc.data(), doc.id))
          .toList();
    }

    return _localMembers
        .where((member) => member.classroomId == classroomId)
        .toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
  }

  Future<Classroom> joinClassroom({
    required AppUser student,
    required String code,
  }) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw ClassroomException('Please enter a class code.');
    }

    if (FirebaseBootstrap.isReady) {
      final roomQuery = await _firestore
          .collection('classrooms')
          .where('code', isEqualTo: normalizedCode)
          .limit(1)
          .get();
      if (roomQuery.docs.isEmpty) {
        throw ClassroomException('Invalid class joining code.');
      }
      final roomDoc = roomQuery.docs.first;
      final room = Classroom.fromMap(roomDoc.data(), roomDoc.id);

      final exists = await _firestore
          .collection('classroom_members')
          .where('classroomId', isEqualTo: room.id)
          .where('studentId', isEqualTo: student.id)
          .limit(1)
          .get();
      if (exists.docs.isNotEmpty) {
        return room;
      }

      final memberDoc = _firestore.collection('classroom_members').doc();
      final member = ClassroomMember(
        id: memberDoc.id,
        classroomId: room.id,
        studentId: student.id,
        studentName: student.name,
        studentEmail: student.email,
        joinedAt: DateTime.now(),
      );
      await memberDoc.set(member.toMap());
      return room;
    }

    final room = _localClassrooms.firstWhere(
      (item) => item.code == normalizedCode,
      orElse: () => throw ClassroomException('Invalid class joining code.'),
    );
    final alreadyJoined = _localMembers.any(
      (member) =>
          member.classroomId == room.id && member.studentId == student.id,
    );
    if (!alreadyJoined) {
      _localMembers.insert(
        0,
        ClassroomMember(
          id: 'member_${DateTime.now().microsecondsSinceEpoch}',
          classroomId: room.id,
          studentId: student.id,
          studentName: student.name,
          studentEmail: student.email,
          joinedAt: DateTime.now(),
        ),
      );
    }
    return room;
  }

  Future<List<Classroom>> fetchClassroomsForStudent(String studentId) async {
    if (FirebaseBootstrap.isReady) {
      final memberSnapshot = await _firestore
          .collection('classroom_members')
          .where('studentId', isEqualTo: studentId)
          .orderBy('joinedAt', descending: true)
          .get();

      final roomIds = memberSnapshot.docs
          .map((doc) => doc.data()['classroomId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (roomIds.isEmpty) {
        return <Classroom>[];
      }

      final classrooms = <Classroom>[];
      for (final roomId in roomIds) {
        final roomDoc = await _firestore
            .collection('classrooms')
            .doc(roomId)
            .get();
        final data = roomDoc.data();
        if (data == null) {
          continue;
        }
        classrooms.add(Classroom.fromMap(data, roomDoc.id));
      }
      classrooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return classrooms;
    }

    final roomIds = _localMembers
        .where((member) => member.studentId == studentId)
        .map((member) => member.classroomId)
        .toSet();

    return _localClassrooms.where((room) => roomIds.contains(room.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<String> _generateUniqueClassCode() async {
    String code = _randomCode();
    if (FirebaseBootstrap.isReady) {
      while (true) {
        final snapshot = await _firestore
            .collection('classrooms')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          break;
        }
        code = _randomCode();
      }
      return code;
    }

    while (_localClassrooms.any((room) => room.code == code)) {
      code = _randomCode();
    }
    return code;
  }

  String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List<String>.generate(
      6,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  String _randomToken(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}

class ClassroomException implements Exception {
  ClassroomException(this.message);

  final String message;

  @override
  String toString() => message;
}
