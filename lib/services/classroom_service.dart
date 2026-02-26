import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/classroom.dart';
import '../models/classroom_member.dart';
import '../models/staff_invite.dart';
import 'firebase_bootstrap.dart';

class ClassroomService {
  static const String _linkHost = 'egatepass-b9da7.web.app';

  final List<StaffInvite> _localInvites = <StaffInvite>[];
  final List<Classroom> _localClassrooms = <Classroom>[];
  final List<ClassroomMember> _localMembers = <ClassroomMember>[];
  final Random _random = Random();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String buildStaffJoinLink(String staffCode) {
    final normalizedCode = _normalizeCode(staffCode);
    if (normalizedCode.isEmpty) {
      return '';
    }
    return Uri.https(_linkHost, '/join', <String, String>{
      'code': normalizedCode,
    }).toString();
  }

  Future<StaffInvite> sendStaffInvitation({
    required String hodId,
    required String section,
    required String staffEmail,
  }) async {
    final token = _randomToken(12);
    final link = Uri.https(_linkHost, '/invite', <String, String>{
      'role': 'teacher',
      'section': section,
      'token': token,
    }).toString();
    if (kDebugMode) {
      debugPrint('Staff invite link: $link');
      debugPrint(
        'Staff dev app link: egatepass://invite?role=teacher&section=${Uri.encodeComponent(section)}&token=$token',
      );
    }
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
          .get();
      final invites = snapshot.docs
          .map((doc) => StaffInvite.fromMap(doc.data(), doc.id))
          .toList();
      invites.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return invites;
    }

    return _localInvites.where((invite) => invite.hodId == hodId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> sendStudentInvitation({
    required Classroom classroom,
    required String studentEmail,
  }) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: studentEmail.trim().toLowerCase(),
      queryParameters: <String, String>{
        'subject': 'Class Joining Invitation - ${classroom.section}',
        'body':
            'You are invited to join ${classroom.section}.\n\nUse this class code to join:\n${classroom.studentCode}\n\nOr use this link:\n${classroom.inviteLink}',
      },
    );

    // Since we can't directly send email from Flutter, we open the email app
    // In a real app, you'd use a backend service to send emails
    // For now, we'll just prepare the URI
    if (kDebugMode) {
      debugPrint('Student invite email URI: $emailUri');
    }
  }

  Future<Classroom> createClassroomByHod({
    required AppUser hod,
    required String year,
    required String department,
    String? sectionSuffix,
  }) async {
    if (hod.role != AppRoles.hod) {
      throw ClassroomException('Only HOD can create class rooms.');
    }

    await _ensureHodCanCreateYear(
      hod: hod,
      year: year,
      sectionSuffix: sectionSuffix,
    );

    final now = DateTime.now();
    final staffCode = await _generateUniqueCode();
    final normalizedSuffix = sectionSuffix?.trim().toUpperCase() ?? '';
    final section = normalizedSuffix.isEmpty
        ? '$year - $department'
        : '$year - $department - $normalizedSuffix';

    final room = Classroom(
      id: '',
      section: section,
      year: year,
      department: department,
      hodId: hod.id,
      teacherId: '',
      teacherName: '',
      teacherEmail: '',
      staffCode: staffCode,
      studentCode: '',
      code: '',
      inviteLink: '',
      createdAt: now,
    );

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('classrooms').doc();
      final saved = room.copyWith(id: doc.id);
      await doc.set(saved.toMap());
      return saved;
    }

    final saved = room.copyWith(
      id: 'class_${DateTime.now().microsecondsSinceEpoch}',
    );
    _localClassrooms.insert(0, saved);
    return saved;
  }

  Future<void> deleteClassroomByHod({
    required AppUser hod,
    required String classroomId,
  }) async {
    if (hod.role != AppRoles.hod) {
      throw ClassroomException('Only HOD can remove class rooms.');
    }

    if (classroomId.trim().isEmpty) {
      throw ClassroomException('Invalid class room id.');
    }

    if (FirebaseBootstrap.isReady) {
      final roomRef = _firestore.collection('classrooms').doc(classroomId);
      final roomSnapshot = await roomRef.get();
      final data = roomSnapshot.data();
      if (data == null) {
        return;
      }
      final room = Classroom.fromMap(data, roomSnapshot.id);
      if (room.hodId != hod.id) {
        throw ClassroomException('You can delete only your own class rooms.');
      }

      final membersSnapshot = await _firestore
          .collection('classroom_members')
          .where('classroomId', isEqualTo: classroomId)
          .get();

      final batch = _firestore.batch();
      for (final memberDoc in membersSnapshot.docs) {
        batch.delete(memberDoc.reference);
      }
      batch.delete(roomRef);
      await batch.commit();
      return;
    }

    final room = _localClassrooms.firstWhere(
      (item) => item.id == classroomId,
      orElse: () => throw ClassroomException('Class room not found.'),
    );
    if (room.hodId != hod.id) {
      throw ClassroomException('You can delete only your own class rooms.');
    }

    _localClassrooms.removeWhere((item) => item.id == classroomId);
    _localMembers.removeWhere((member) => member.classroomId == classroomId);
  }

  Future<Classroom> createClassroom({
    required String section,
    required AppUser teacher,
  }) async {
    final now = DateTime.now();
    final staffCode = await _generateUniqueCode();
    final studentCode = await _generateUniqueCode();
    final inviteLink = Uri.https(_linkHost, '/join', <String, String>{
      'code': studentCode,
    }).toString();
    if (kDebugMode) {
      debugPrint('Class invite link: $inviteLink');
      debugPrint('Staff code: $staffCode');
      debugPrint('Student code: $studentCode');
      debugPrint('Dev app link: egatepass://join?code=$studentCode');
    }

    final room = Classroom(
      id: '',
      section: section,
      year: teacher.year ?? section,
      department: teacher.department,
      hodId: '',
      teacherId: teacher.id,
      teacherName: teacher.name,
      teacherEmail: teacher.email,
      staffCode: staffCode,
      studentCode: studentCode,
      code: studentCode,
      inviteLink: inviteLink,
      createdAt: now,
    );

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('classrooms').doc();
      final saved = room.copyWith(id: doc.id);
      await doc.set(saved.toMap());
      return saved;
    }

    final saved = room.copyWith(
      id: 'class_${DateTime.now().microsecondsSinceEpoch}',
    );
    _localClassrooms.insert(0, saved);
    return saved;
  }

  Future<List<Classroom>> fetchClassroomsForHod(String hodId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('classrooms')
          .where('hodId', isEqualTo: hodId)
          .get();
      final rooms = snapshot.docs
          .map((doc) => Classroom.fromMap(doc.data(), doc.id))
          .toList();
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
    }

    return _localClassrooms.where((room) => room.hodId == hodId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Classroom>> fetchClassroomsForTeacher(String teacherId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('classrooms')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final rooms = snapshot.docs
          .map((doc) => Classroom.fromMap(doc.data(), doc.id))
          .toList();
      rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return rooms;
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
          .get();
      final members = snapshot.docs
          .map((doc) => ClassroomMember.fromMap(doc.data(), doc.id))
          .toList();
      members.sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
      return members;
    }

    return _localMembers
        .where((member) => member.classroomId == classroomId)
        .toList()
      ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
  }

  Future<Classroom> joinClassroomAsStaff({
    required AppUser staff,
    required String code,
  }) async {
    if (staff.role != AppRoles.teacher) {
      throw ClassroomException('Only staff can use staff class code.');
    }

    final normalizedCode = _normalizeCode(code);
    if (normalizedCode.isEmpty) {
      throw ClassroomException('Please enter staff class code.');
    }

    if (FirebaseBootstrap.isReady) {
      final roomQuery = await _firestore
          .collection('classrooms')
          .where('staffCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();
      if (roomQuery.docs.isEmpty) {
        throw ClassroomException('Invalid staff class code.');
      }

      final roomDoc = roomQuery.docs.first;
      final room = Classroom.fromMap(roomDoc.data(), roomDoc.id);
      _ensureDepartmentMatch(room: room, user: staff);

      if (room.teacherId.isNotEmpty && room.teacherId != staff.id) {
        throw ClassroomException(
          'This class is already assigned to another staff.',
        );
      }
      if (room.teacherId == staff.id) {
        return room;
      }

      var studentCode = room.studentCode;
      var inviteLink = room.inviteLink;
      if (studentCode.isEmpty) {
        studentCode = await _generateUniqueCode();
        inviteLink = Uri.https(_linkHost, '/join', <String, String>{
          'code': studentCode,
        }).toString();
      }

      final updated = room.copyWith(
        teacherId: staff.id,
        teacherName: staff.name,
        teacherEmail: staff.email,
        studentCode: studentCode,
        code: studentCode,
        inviteLink: inviteLink,
      );

      await roomDoc.reference.update(updated.toMap());
      return updated;
    }

    final index = _localClassrooms.indexWhere(
      (room) => room.staffCode == normalizedCode,
    );
    if (index < 0) {
      throw ClassroomException('Invalid staff class code.');
    }

    final room = _localClassrooms[index];
    _ensureDepartmentMatch(room: room, user: staff);
    if (room.teacherId.isNotEmpty && room.teacherId != staff.id) {
      throw ClassroomException(
        'This class is already assigned to another staff.',
      );
    }
    if (room.teacherId == staff.id) {
      return room;
    }

    var studentCode = room.studentCode;
    var inviteLink = room.inviteLink;
    if (studentCode.isEmpty) {
      studentCode = await _generateUniqueCode();
      inviteLink = Uri.https(_linkHost, '/join', <String, String>{
        'code': studentCode,
      }).toString();
    }

    final updated = room.copyWith(
      teacherId: staff.id,
      teacherName: staff.name,
      teacherEmail: staff.email,
      studentCode: studentCode,
      code: studentCode,
      inviteLink: inviteLink,
    );
    _localClassrooms[index] = updated;
    return updated;
  }

  Future<Classroom> joinClassroomAsStudent({
    required AppUser student,
    required String code,
  }) async {
    if (student.role != AppRoles.student) {
      throw ClassroomException('Only students can use student class code.');
    }

    final normalizedCode = _normalizeCode(code);
    if (normalizedCode.isEmpty) {
      throw ClassroomException('Please enter student class code.');
    }

    if (FirebaseBootstrap.isReady) {
      QuerySnapshot<Map<String, dynamic>> roomQuery = await _firestore
          .collection('classrooms')
          .where('studentCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (roomQuery.docs.isEmpty) {
        roomQuery = await _firestore
            .collection('classrooms')
            .where('code', isEqualTo: normalizedCode)
            .limit(1)
            .get();
      }

      if (roomQuery.docs.isEmpty) {
        throw ClassroomException('Invalid student class code.');
      }

      final roomDoc = roomQuery.docs.first;
      final room = Classroom.fromMap(roomDoc.data(), roomDoc.id);
      if (room.teacherId.isEmpty) {
        throw ClassroomException(
          'Staff not assigned yet. Ask your staff for the student code.',
        );
      }
      _ensureDepartmentMatch(room: room, user: student);

      final studentMemberships = await _firestore
          .collection('classroom_members')
          .where('studentId', isEqualTo: student.id)
          .get();
      final alreadyJoined = studentMemberships.docs.any((doc) {
        final data = doc.data();
        return (data['classroomId'] as String? ?? '') == room.id;
      });
      if (alreadyJoined) {
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
      (item) =>
          item.studentCode == normalizedCode || item.code == normalizedCode,
      orElse: () => throw ClassroomException('Invalid student class code.'),
    );

    if (room.teacherId.isEmpty) {
      throw ClassroomException(
        'Staff not assigned yet. Ask your staff for the student code.',
      );
    }
    _ensureDepartmentMatch(room: room, user: student);

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

  Future<Classroom> joinClassroom({
    required AppUser student,
    required String code,
  }) async {
    if (student.role == AppRoles.teacher) {
      return joinClassroomAsStaff(staff: student, code: code);
    }
    if (student.role == AppRoles.student) {
      return joinClassroomAsStudent(student: student, code: code);
    }
    throw ClassroomException('Only staff and students can join classroom.');
  }

  Future<List<Classroom>> fetchClassroomsForStudent(String studentId) async {
    if (FirebaseBootstrap.isReady) {
      final memberSnapshot = await _firestore
          .collection('classroom_members')
          .where('studentId', isEqualTo: studentId)
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

  Future<Set<String>> fetchStudentClassroomIds(String studentId) async {
    if (FirebaseBootstrap.isReady) {
      final memberSnapshot = await _firestore
          .collection('classroom_members')
          .where('studentId', isEqualTo: studentId)
          .get();
      return memberSnapshot.docs
          .map((doc) => doc.data()['classroomId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    return _localMembers
        .where((member) => member.studentId == studentId)
        .map((member) => member.classroomId)
        .toSet();
  }

  Future<void> _ensureHodCanCreateYear({
    required AppUser hod,
    required String year,
    String? sectionSuffix,
  }) async {
    final existing = await fetchClassroomsForHod(hod.id);
    final isFirstYearHodType = isFirstYearHod(hod.hodType);
    final normalizedSuffix = sectionSuffix?.trim().toUpperCase() ?? '';

    if (isFirstYearHodType) {
      if (year != classYears.first) {
        throw ClassroomException(
          'First year HOD can create only I Year class.',
        );
      }
      if (existing.length >= 3) {
        throw ClassroomException(
          'First year HOD can keep at most three classes.',
        );
      }
    } else {
      const seniorYears = <String>['II Year', 'III Year', 'IV Year'];
      if (!seniorYears.contains(year)) {
        throw ClassroomException(
          'Senior HOD can create only II Year, III Year and IV Year classes.',
        );
      }
    }

    final sameYear = existing.where((room) => room.year == year).toList();
    if (sameYear.length >= 3) {
      throw ClassroomException(
        'Maximum three classes already exist for $year.',
      );
    }

    final duplicate = existing.any((room) {
      if (room.year != year) {
        return false;
      }
      if (normalizedSuffix.isEmpty) {
        return true;
      }
      return room.section.trim().toUpperCase().endsWith(' - $normalizedSuffix');
    });
    if (duplicate) {
      if (normalizedSuffix.isEmpty) {
        throw ClassroomException('Class already exists for $year.');
      }
      throw ClassroomException(
        'Class already exists for $year section $normalizedSuffix.',
      );
    }
  }

  void _ensureDepartmentMatch({
    required Classroom room,
    required AppUser user,
  }) {
    if (room.department.isEmpty) {
      return;
    }
    if (room.department != user.department) {
      throw ClassroomException(
        'This class is for ${room.department}. Your department is ${user.department}.',
      );
    }
  }

  String _normalizeCode(String code) => code.trim().toUpperCase();

  Future<String> _generateUniqueCode() async {
    var code = _randomCode();
    while (await _codeAlreadyUsed(code)) {
      code = _randomCode();
    }
    return code;
  }

  Future<bool> _codeAlreadyUsed(String code) async {
    if (FirebaseBootstrap.isReady) {
      final staffSnap = await _firestore
          .collection('classrooms')
          .where('staffCode', isEqualTo: code)
          .limit(1)
          .get();
      if (staffSnap.docs.isNotEmpty) {
        return true;
      }

      final studentSnap = await _firestore
          .collection('classrooms')
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();
      if (studentSnap.docs.isNotEmpty) {
        return true;
      }

      final legacySnap = await _firestore
          .collection('classrooms')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      return legacySnap.docs.isNotEmpty;
    }

    return _localClassrooms.any((room) {
      return room.staffCode == code ||
          room.studentCode == code ||
          room.code == code;
    });
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
