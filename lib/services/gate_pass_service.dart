import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/classroom.dart';
import '../models/gate_pass_request.dart';
import 'firebase_bootstrap.dart';

class GatePassService {
  final List<GatePassRequest> _localRequests = <GatePassRequest>[];

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
    if (request.teacherId != teacher.id) {
      throw GatePassException('This request is not assigned to your class.');
    }
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
    );
  }
}

class GatePassException implements Exception {
  GatePassException(this.message);

  final String message;

  @override
  String toString() => message;
}
