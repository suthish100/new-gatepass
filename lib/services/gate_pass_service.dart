import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/classroom.dart';
import '../models/gate_pass_request.dart';
import 'delegation_service.dart';
import 'firebase_bootstrap.dart';

class GatePassService {
  GatePassService({DelegationService? delegationService})
      : _delegationService = delegationService;

  final List<GatePassRequest> _localRequests = <GatePassRequest>[];
  final DelegationService? _delegationService;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<GatePassRequest> createRequest({
    required AppUser student,
    required Classroom classroom,
    required String registerNumber,
    required String passType,
    required DateTime date,
    required String outTime,
    required String inTime,
    required String reason,
    // Leave pass specific
    DateTime? fromDate,
    DateTime? toDate,
    String? destination,
    String? parentContact,
  }) async {
    if (student.role != AppRoles.student) {
      throw GatePassException('Only students can create pass requests.');
    }
    if (classroom.teacherId.isEmpty) {
      throw GatePassException('Class incharge not assigned for this class.');
    }
    if (classroom.hodId.isEmpty) {
      throw GatePassException('HOD not mapped for this class.');
    }

    // Flaw 4 fix: Check for existing active pass to prevent duplicate submissions
    await _ensureNoActivePass(studentId: student.id);

    final request = GatePassRequest(
      id: '',
      studentId: student.id,
      studentName: student.name,
      registerNumber: registerNumber.trim(),
      studentClass: classroom.year,
      department: student.department,
      classroomId: classroom.id,
      classroomSection: classroom.section,
      teacherId: classroom.teacherId,
      hodId: classroom.hodId,
      passType: passType,
      date: date,
      outTime: outTime.trim(),
      inTime: inTime.trim(),
      reason: reason.trim(),
      status: RequestStatus.pendingTeacher,
      createdAt: DateTime.now(),
      fromDate: fromDate,
      toDate: toDate,
      destination: destination?.trim(),
      parentContact: parentContact?.trim(),
    );

    if (FirebaseBootstrap.isReady) {
      final doc = _firestore.collection('gate_pass_requests').doc();
      final newRequest = request.copyWith(id: doc.id);
      await doc.set(newRequest.toMap());
      return newRequest;
    }

    final local = request.copyWith(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
    );
    _localRequests.insert(0, local);
    return local;
  }

  Future<void> _ensureNoActivePass({required String studentId}) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('studentId', isEqualTo: studentId)
          .get();
      final hasPendingTeacher = snapshot.docs.any((doc) {
        return (doc.data()['status'] as String? ?? '') ==
            RequestStatus.pendingTeacher;
      });
      if (hasPendingTeacher) {
        throw GatePassException(
          'You already have a pending pass request awaiting Class Incharge approval. '
          'Please wait for it to be processed before creating a new one.',
        );
      }

      final hasPendingHod = snapshot.docs.any((doc) {
        return (doc.data()['status'] as String? ?? '') ==
            RequestStatus.forwardedToHod;
      });
      if (hasPendingHod) {
        throw GatePassException(
          'You already have a pass request awaiting HOD approval. '
          'Please wait for it to be processed before creating a new one.',
        );
      }
      return;
    }

    final hasActive = _localRequests.any(
      (r) =>
          r.studentId == studentId &&
          (r.status == RequestStatus.pendingTeacher ||
              r.status == RequestStatus.forwardedToHod),
    );
    if (hasActive) {
      throw GatePassException(
        'You already have a pending pass request. '
        'Please wait for it to be processed before creating a new one.',
      );
    }
  }

  Future<List<GatePassRequest>> fetchStudentRequests(String studentId) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('studentId', isEqualTo: studentId)
          .get();
      final requests = snapshot.docs
          .map((doc) => GatePassRequest.fromMap(doc.data(), doc.id))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    }

    return _localRequests
        .where((request) => request.studentId == studentId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<GatePassRequest?> fetchPassById(String passId) async {
    if (FirebaseBootstrap.isReady) {
      final doc = await _firestore
          .collection('gate_pass_requests')
          .doc(passId)
          .get();
      final data = doc.data();
      if (data == null) return null;
      return GatePassRequest.fromMap(data, doc.id);
    }
    try {
      return _localRequests.firstWhere((r) => r.id == passId);
    } catch (_) {
      return null;
    }
  }

  Future<List<GatePassRequest>> fetchTeacherRequests({
    required String teacherId,
    bool onlyOpen = false,
  }) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      final requests = snapshot.docs
          .map((doc) => GatePassRequest.fromMap(doc.data(), doc.id))
          .where(
            (request) =>
                !onlyOpen || request.status == RequestStatus.pendingTeacher,
          )
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    }

    return _localRequests
        .where((request) => request.teacherId == teacherId)
        .where(
          (request) =>
              !onlyOpen || request.status == RequestStatus.pendingTeacher,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<GatePassRequest>> fetchTeacherActionableRequests({
    required AppUser teacher,
    bool onlyOpen = false,
  }) async {
    final ownRequests = await fetchTeacherRequests(
      teacherId: teacher.id,
      onlyOpen: onlyOpen,
    );

    final delegationService = _delegationService;
    if (delegationService == null) {
      return ownRequests;
    }

    final activeDelegations = await delegationService
        .fetchActiveDelegationsForDelegate(teacher.id);
    if (activeDelegations.isEmpty) {
      return ownRequests;
    }

    final ownerIds = activeDelegations
        .map((item) => item.ownerTeacherId)
        .toSet()
        .where((ownerId) => ownerId != teacher.id)
        .toList();
    if (ownerIds.isEmpty) {
      return ownRequests;
    }

    final all = <GatePassRequest>[...ownRequests];
    for (final ownerId in ownerIds) {
      final requests = await fetchTeacherRequests(
        teacherId: ownerId,
        onlyOpen: onlyOpen,
      );
      all.addAll(requests);
    }

    final uniqueById = <String, GatePassRequest>{};
    for (final request in all) {
      uniqueById[request.id] = request;
    }
    final unique = uniqueById.values.toList();
    unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return unique;
  }

  Future<List<GatePassRequest>> fetchHodRequests({
    required String hodId,
    bool onlyOpen = false,
  }) async {
    if (FirebaseBootstrap.isReady) {
      final snapshot = await _firestore
          .collection('gate_pass_requests')
          .where('hodId', isEqualTo: hodId)
          .get();
      final requests = snapshot.docs
          .map((doc) => GatePassRequest.fromMap(doc.data(), doc.id))
          .where(
            (request) =>
                !onlyOpen || request.status == RequestStatus.forwardedToHod,
          )
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    }

    return _localRequests
        .where((request) => request.hodId == hodId)
        .where(
          (request) =>
              !onlyOpen || request.status == RequestStatus.forwardedToHod,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> teacherAction({
    required GatePassRequest request,
    required AppUser teacher,
    required bool approve,
    String? cancelReason,
  }) async {
    if (teacher.role != AppRoles.teacher) {
      throw GatePassException('Only class incharge can review this request.');
    }

    final authority = await _resolveTeacherAuthority(
      request: request,
      actor: teacher,
    );
    if (request.status != RequestStatus.pendingTeacher) {
      throw GatePassException(
        'Request is already processed by class incharge.',
      );
    }

    final nextStatus = approve
        ? RequestStatus.forwardedToHod
        : RequestStatus.rejectedByTeacher;
    await _updateRequestStatus(
      requestId: request.id,
      status: nextStatus,
      actedBy: '${teacher.name} (${teacher.role})',
      cancelReason: approve ? null : cancelReason,
      teacherActionAt: DateTime.now(),
      teacherActionActorId: authority.actorId,
      teacherActionActorName: authority.actorName,
      teacherRoleUsedId: authority.roleUsedId,
      teacherRoleUsedName: authority.roleUsedName,
      teacherActionAuthorityReason: authority.authorityReason,
      teacherDelegationRefId: authority.delegationRefId,
    );
  }

  Future<void> hodAction({
    required GatePassRequest request,
    required AppUser hod,
    required bool approve,
    String? cancelReason,
  }) async {
    if (hod.role != AppRoles.hod) {
      throw GatePassException('Only HOD can give final approval.');
    }
    if (request.hodId != hod.id) {
      throw GatePassException(
        'This request is not assigned to your dashboard.',
      );
    }
    if (request.status != RequestStatus.forwardedToHod) {
      throw GatePassException('Request is not waiting for HOD approval.');
    }

    final nextStatus = approve
        ? RequestStatus.approved
        : RequestStatus.rejectedByHod;
    await _updateRequestStatus(
      requestId: request.id,
      status: nextStatus,
      actedBy: '${hod.name} (${hod.role})',
      cancelReason: approve ? null : cancelReason,
      hodActionAt: DateTime.now(),
      approvedAt: approve ? DateTime.now() : null,
    );
  }

  Future<void> _updateRequestStatus({
    required String requestId,
    required String status,
    required String actedBy,
    String? cancelReason,
    DateTime? teacherActionAt,
    DateTime? hodActionAt,
    DateTime? approvedAt,
    String? teacherActionActorId,
    String? teacherActionActorName,
    String? teacherRoleUsedId,
    String? teacherRoleUsedName,
    String? teacherActionAuthorityReason,
    String? teacherDelegationRefId,
  }) async {
    final trimmedReason = cancelReason?.trim();

    if (FirebaseBootstrap.isReady) {
      final patch = <String, dynamic>{
        'status': status,
        'lastActionBy': actedBy,
        'cancelReason': (trimmedReason ?? '').isEmpty ? null : trimmedReason,
      };
      if (teacherActionAt != null) {
        patch['teacherActionAt'] = Timestamp.fromDate(teacherActionAt);
      }
      if (teacherActionActorId != null) {
        patch['teacherActionActorId'] = teacherActionActorId;
      }
      if (teacherActionActorName != null) {
        patch['teacherActionActorName'] = teacherActionActorName;
      }
      if (teacherRoleUsedId != null) {
        patch['teacherRoleUsedId'] = teacherRoleUsedId;
      }
      if (teacherRoleUsedName != null) {
        patch['teacherRoleUsedName'] = teacherRoleUsedName;
      }
      if (teacherActionAuthorityReason != null) {
        patch['teacherActionAuthorityReason'] = teacherActionAuthorityReason;
      }
      if (teacherDelegationRefId != null) {
        patch['teacherDelegationRefId'] = teacherDelegationRefId;
      }
      if (hodActionAt != null) {
        patch['hodActionAt'] = Timestamp.fromDate(hodActionAt);
      }
      if (approvedAt != null) {
        patch['approvedAt'] = Timestamp.fromDate(approvedAt);
      }

      await _firestore
          .collection('gate_pass_requests')
          .doc(requestId)
          .update(patch);
      return;
    }

    final index = _localRequests.indexWhere(
      (request) => request.id == requestId,
    );
    if (index == -1) return;
    _localRequests[index] = _localRequests[index].copyWith(
      status: status,
      lastActionBy: actedBy,
      cancelReason: (trimmedReason ?? '').isEmpty ? null : trimmedReason,
      teacherActionAt: teacherActionAt,
      hodActionAt: hodActionAt,
      approvedAt: approvedAt,
      teacherActionActorId: teacherActionActorId,
      teacherActionActorName: teacherActionActorName,
      teacherRoleUsedId: teacherRoleUsedId,
      teacherRoleUsedName: teacherRoleUsedName,
      teacherActionAuthorityReason: teacherActionAuthorityReason,
      teacherDelegationRefId: teacherDelegationRefId,
    );
  }

  Future<_TeacherActionAuthority> _resolveTeacherAuthority({
    required GatePassRequest request,
    required AppUser actor,
  }) async {
    if (request.teacherId == actor.id) {
      return _TeacherActionAuthority(
        actorId: actor.id,
        actorName: actor.name,
        roleUsedId: actor.id,
        roleUsedName: actor.name,
        authorityReason: 'Primary class incharge',
        delegationRefId: null,
      );
    }

    final delegationService = _delegationService;
    if (delegationService == null) {
      throw GatePassException('This request is not assigned to your class.');
    }

    final delegation = await delegationService.findActiveTeacherDelegation(
      ownerTeacherId: request.teacherId,
      delegateTeacherId: actor.id,
      classroomId: request.classroomId,
    );
    if (delegation == null) {
      throw GatePassException('No active delegation found for this class.');
    }

    return _TeacherActionAuthority(
      actorId: actor.id,
      actorName: actor.name,
      roleUsedId: delegation.ownerTeacherId,
      roleUsedName: delegation.ownerTeacherName,
      authorityReason:
          'Delegate period active (${delegation.startAt.toIso8601String()} to ${delegation.endAt.toIso8601String()})',
      delegationRefId: delegation.id,
    );
  }
}

class _TeacherActionAuthority {
  const _TeacherActionAuthority({
    required this.actorId,
    required this.actorName,
    required this.roleUsedId,
    required this.roleUsedName,
    required this.authorityReason,
    required this.delegationRefId,
  });

  final String actorId;
  final String actorName;
  final String roleUsedId;
  final String roleUsedName;
  final String authorityReason;
  final String? delegationRefId;
}

class GatePassException implements Exception {
  GatePassException(this.message);

  final String message;

  @override
  String toString() => message;
}
