import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/app_user.dart';
import '../models/classroom.dart';
import '../models/gate_pass_request.dart';
import '../models/gate_pass_scan_log.dart';
import '../models/gate_pass_verification.dart';
import 'classroom_service.dart';
import 'delegation_service.dart';
import 'firebase_bootstrap.dart';

class GatePassService {
  GatePassService({
    DelegationService? delegationService,
    ClassroomService? classroomService,
  }) : _delegationService = delegationService,
       _classroomService = classroomService;

  final List<GatePassRequest> _localRequests = <GatePassRequest>[];
  final DelegationService? _delegationService;
  final ClassroomService? _classroomService;

  static const String _cachedPassesKey = 'gate_pass_cached_passes_v2';
  static const String _scanHistoryKey = 'gate_pass_scan_history_v2';
  static const int _maxCachedPasses = 250;
  static const int _maxStoredScanLogs = 100;

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
      studentPhotoBase64: student.profileImageBase64,
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
      final request = GatePassRequest.fromMap(data, doc.id);
      await _cachePass(request);
      return request;
    }
    try {
      final request = _localRequests.firstWhere((r) => r.id == passId);
      await _cachePass(request);
      return request;
    } catch (_) {
      return _readCachedPass(passId);
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

  Future<String> teacherAction({
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

    final delegatedFinalApproval = approve
        ? await _getActiveHodDelegatedFinalApproval(
            classroomId: request.classroomId,
            teacherId: teacher.id,
          )
        : null;
    final isSingleApproverActive = delegatedFinalApproval != null;
    final nextStatus = approve
        ? (isSingleApproverActive
              ? RequestStatus.approved
              : RequestStatus.forwardedToHod)
        : RequestStatus.rejectedByTeacher;
    final actionTime = DateTime.now();
    final singleApproverReason = !isSingleApproverActive
        ? authority.authorityReason
        : 'Final approval delegated by HOD until '
                  '${delegatedFinalApproval.hodDelegationEndAt?.toIso8601String() ?? ''}. '
                  '${delegatedFinalApproval.hodDelegationReason ?? ''}'
              .trim();
    await _updateRequestStatus(
      requestId: request.id,
      status: nextStatus,
      actedBy: isSingleApproverActive
          ? '${teacher.name} (${teacher.role} + HOD Delegate)'
          : '${teacher.name} (${teacher.role})',
      cancelReason: approve ? null : cancelReason,
      teacherActionAt: actionTime,
      teacherActionActorId: authority.actorId,
      teacherActionActorName: authority.actorName,
      teacherRoleUsedId: authority.roleUsedId,
      teacherRoleUsedName: authority.roleUsedName,
      teacherActionAuthorityReason: singleApproverReason,
      teacherDelegationRefId: authority.delegationRefId,
      hodActionAt: isSingleApproverActive ? actionTime : null,
      approvedAt: isSingleApproverActive ? actionTime : null,
    );
    return nextStatus;
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

  String normalizeScanInput(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('EGATEPASS|')) {
      final parts = value.split('|');
      if (parts.length >= 2) {
        return parts[1].trim();
      }
    }
    return value;
  }

  Future<GatePassVerification> verifyPassForScan({
    required String rawCode,
    String scanSource = 'camera',
    String verifiedBy = 'Security Gate',
    String deviceLabel = 'security-app',
  }) async {
    final passId = normalizeScanInput(rawCode);
    final scannedAt = DateTime.now();
    if (passId.isEmpty) {
      final verification = _buildVerification(
        status: GatePassVerificationStatus.error,
        passId: '',
        request: null,
        message: 'QR code is empty or unreadable.',
        scannedAt: scannedAt,
        scanSource: scanSource,
        wasOffline: false,
        pendingSync: false,
      );
      await _storeScanLog(verification.historyLog);
      return verification;
    }

    if (FirebaseBootstrap.isReady) {
      try {
        final verification = await _verifyPassOnline(
          passId: passId,
          scanSource: scanSource,
          verifiedBy: verifiedBy,
          deviceLabel: deviceLabel,
        );
        await syncPendingOfflineScans();
        return verification;
      } catch (_) {
        final cachedPass = await _readCachedPass(passId);
        if (cachedPass != null) {
          return _verifyPassOffline(
            pass: cachedPass,
            scanSource: scanSource,
            verifiedBy: verifiedBy,
            deviceLabel: deviceLabel,
          );
        }
      }
    }

    final localPass = _findLocalPass(passId) ?? await _readCachedPass(passId);
    if (localPass != null) {
      return _verifyPassOffline(
        pass: localPass,
        scanSource: scanSource,
        verifiedBy: verifiedBy,
        deviceLabel: deviceLabel,
      );
    }

    final verification = _buildVerification(
      status: GatePassVerificationStatus.notFound,
      passId: passId,
      request: null,
      message: 'Invalid QR or unknown pass.',
      scannedAt: scannedAt,
      scanSource: scanSource,
      wasOffline: !FirebaseBootstrap.isReady,
      pendingSync: false,
    );
    await _storeScanLog(verification.historyLog);
    return verification;
  }

  Future<List<GatePassScanLog>> fetchRecentScanHistory({int limit = 10}) async {
    final logs = await _readStoredScanLogs();
    logs.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return logs.take(limit).toList();
  }

  Future<void> syncPendingOfflineScans() async {
    if (!FirebaseBootstrap.isReady) return;

    final logs = await _readStoredScanLogs();
    if (logs.isEmpty) return;

    var changed = false;
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      if (!log.pendingSync ||
          log.outcome != GatePassVerificationStatus.approved.name) {
        continue;
      }

      try {
        final docRef = _firestore
            .collection('gate_pass_requests')
            .doc(log.passId);
        final historyRef = _firestore
            .collection('gate_pass_scan_history')
            .doc();
        GatePassRequest? syncedPass;

        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          final data = snapshot.data();
          if (data == null) {
            return;
          }

          final currentPass = GatePassRequest.fromMap(data, snapshot.id);
          syncedPass = currentPass;
          if (currentPass.usedAt == null) {
            transaction.update(docRef, <String, dynamic>{
              'usedAt': Timestamp.fromDate(log.scannedAt),
              'usedBy': 'Security Gate',
              'usedByDevice': 'offline-sync',
            });
            syncedPass = currentPass.copyWith(
              usedAt: log.scannedAt,
              usedBy: 'Security Gate',
              usedByDevice: 'offline-sync',
            );
          }

          transaction.set(historyRef, log.copyWith(pendingSync: false).toMap());
        });

        if (syncedPass != null) {
          _replaceLocalPass(syncedPass!);
          await _cachePass(syncedPass!);
        }
        logs[i] = log.copyWith(pendingSync: false);
        changed = true;
      } catch (_) {
        // Keep the entry pending for a later retry.
      }
    }

    if (changed) {
      await _writeStoredScanLogs(logs);
    }
  }

  Future<GatePassVerification> _verifyPassOnline({
    required String passId,
    required String scanSource,
    required String verifiedBy,
    required String deviceLabel,
  }) async {
    final docRef = _firestore.collection('gate_pass_requests').doc(passId);
    final historyRef = _firestore.collection('gate_pass_scan_history').doc();

    final verification = await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      final scannedAt = DateTime.now();

      if (data == null) {
        final result = _buildVerification(
          status: GatePassVerificationStatus.notFound,
          passId: passId,
          request: null,
          message: 'Invalid QR or unknown pass.',
          scannedAt: scannedAt,
          scanSource: scanSource,
          wasOffline: false,
          pendingSync: false,
          historyId: historyRef.id,
        );
        transaction.set(historyRef, result.historyLog.toMap());
        return result;
      }

      var pass = GatePassRequest.fromMap(data, snapshot.id);
      final status = _evaluatePassStatus(pass, scannedAt);
      final message = _verificationMessage(pass, status, scannedAt);
      final shouldMarkUsed = status == GatePassVerificationStatus.approved;

      if (shouldMarkUsed) {
        transaction.update(docRef, <String, dynamic>{
          'usedAt': Timestamp.fromDate(scannedAt),
          'usedBy': verifiedBy,
          'usedByDevice': deviceLabel,
        });
        pass = pass.copyWith(
          usedAt: scannedAt,
          usedBy: verifiedBy,
          usedByDevice: deviceLabel,
        );
      }

      final result = _buildVerification(
        status: status,
        passId: passId,
        request: pass,
        message: message,
        scannedAt: scannedAt,
        scanSource: scanSource,
        wasOffline: false,
        pendingSync: false,
        usedNow: shouldMarkUsed,
        historyId: historyRef.id,
      );
      transaction.set(historyRef, result.historyLog.toMap());
      return result;
    });

    if (verification.request != null) {
      await _cachePass(verification.request!);
    }
    await _storeScanLog(verification.historyLog);
    return verification;
  }

  Future<GatePassVerification> _verifyPassOffline({
    required GatePassRequest pass,
    required String scanSource,
    required String verifiedBy,
    required String deviceLabel,
  }) async {
    final scannedAt = DateTime.now();
    final status = _evaluatePassStatus(pass, scannedAt);
    final shouldMarkUsed = status == GatePassVerificationStatus.approved;
    final offlinePass = shouldMarkUsed
        ? pass.copyWith(
            usedAt: scannedAt,
            usedBy: verifiedBy,
            usedByDevice: deviceLabel,
          )
        : pass;

    final verification = _buildVerification(
      status: status,
      passId: pass.id,
      request: offlinePass,
      message: _verificationMessage(pass, status, scannedAt),
      scannedAt: scannedAt,
      scanSource: scanSource,
      wasOffline: true,
      pendingSync: shouldMarkUsed,
      usedNow: shouldMarkUsed,
    );

    _replaceLocalPass(offlinePass);
    await _cachePass(offlinePass);
    await _storeScanLog(verification.historyLog);
    return verification;
  }

  GatePassVerificationStatus _evaluatePassStatus(
    GatePassRequest pass,
    DateTime scannedAt,
  ) {
    if (!pass.isApproved) {
      return GatePassVerificationStatus.notApproved;
    }
    if (!pass.isValidOn(scannedAt)) {
      return GatePassVerificationStatus.expired;
    }
    if (pass.isUsed) {
      return GatePassVerificationStatus.alreadyUsed;
    }
    return GatePassVerificationStatus.approved;
  }

  String _verificationMessage(
    GatePassRequest pass,
    GatePassVerificationStatus status,
    DateTime scannedAt,
  ) {
    switch (status) {
      case GatePassVerificationStatus.approved:
        return 'HOD approved. Exit allowed.';
      case GatePassVerificationStatus.expired:
        if (pass.isLeavePass) {
          return 'Pass is expired for the selected leave dates.';
        }
        return 'This outing pass is valid only on ${_formatDate(pass.date)}.';
      case GatePassVerificationStatus.alreadyUsed:
        final usedAt = pass.usedAt;
        if (usedAt == null) {
          return 'This pass has already been used.';
        }
        return 'Already used at ${_formatDateTime(usedAt)}.';
      case GatePassVerificationStatus.notApproved:
        return pass.status == RequestStatus.rejectedByTeacher ||
                pass.status == RequestStatus.rejectedByHod
            ? 'Pass was rejected and cannot be used.'
            : 'Pass is not fully approved yet.';
      case GatePassVerificationStatus.notFound:
        return 'Invalid QR or unknown pass.';
      case GatePassVerificationStatus.error:
        return 'Unable to verify this QR code.';
    }
  }

  GatePassVerification _buildVerification({
    required GatePassVerificationStatus status,
    required String passId,
    required GatePassRequest? request,
    required String message,
    required DateTime scannedAt,
    required String scanSource,
    required bool wasOffline,
    required bool pendingSync,
    bool usedNow = false,
    String? historyId,
  }) {
    final log = GatePassScanLog(
      id: historyId ?? 'scan_${scannedAt.microsecondsSinceEpoch}',
      passId: passId,
      outcome: status.name,
      message: message,
      scannedAt: scannedAt,
      scanSource: scanSource,
      wasOffline: wasOffline,
      pendingSync: pendingSync,
      studentId: request?.studentId,
      studentName: request?.studentName,
      registerNumber: request?.registerNumber,
      passType: request?.passType,
    );

    return GatePassVerification(
      status: status,
      passId: passId,
      request: request,
      message: message,
      scannedAt: scannedAt,
      historyLog: log,
      usedNow: usedNow,
      wasOffline: wasOffline,
    );
  }

  GatePassRequest? _findLocalPass(String passId) {
    for (final request in _localRequests) {
      if (request.id == passId) {
        return request;
      }
    }
    return null;
  }

  void _replaceLocalPass(GatePassRequest pass) {
    final index = _localRequests.indexWhere((item) => item.id == pass.id);
    if (index != -1) {
      _localRequests[index] = pass;
    }
  }

  Future<void> _cachePass(GatePassRequest pass) async {
    final cached = await _readCachedPasses();
    final byId = <String, GatePassRequest>{
      for (final item in cached) item.id: item,
    };
    byId[pass.id] = pass;
    final next = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeCachedPasses(next.take(_maxCachedPasses).toList());
  }

  Future<GatePassRequest?> _readCachedPass(String passId) async {
    final cached = await _readCachedPasses();
    for (final pass in cached) {
      if (pass.id == passId) {
        return pass;
      }
    }
    return null;
  }

  Future<List<GatePassRequest>> _readCachedPasses() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_cachedPassesKey) ?? <String>[];
    final passes = <GatePassRequest>[];
    for (final item in rawList) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        passes.add(GatePassRequest.fromJson(decoded));
      } catch (_) {
        // Skip malformed cache entries.
      }
    }
    return passes;
  }

  Future<void> _writeCachedPasses(List<GatePassRequest> passes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cachedPassesKey,
      passes.map((pass) => jsonEncode(pass.toJson())).toList(),
    );
  }

  Future<void> _storeScanLog(GatePassScanLog log) async {
    final logs = await _readStoredScanLogs();
    final next = <GatePassScanLog>[
      log,
      ...logs.where((entry) => entry.id != log.id),
    ]..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    await _writeStoredScanLogs(next.take(_maxStoredScanLogs).toList());
  }

  Future<List<GatePassScanLog>> _readStoredScanLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_scanHistoryKey) ?? <String>[];
    final logs = <GatePassScanLog>[];
    for (final item in rawList) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        logs.add(GatePassScanLog.fromJson(decoded));
      } catch (_) {
        // Skip malformed cache entries.
      }
    }
    return logs;
  }

  Future<void> _writeStoredScanLogs(List<GatePassScanLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scanHistoryKey,
      logs.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  String _formatDate(DateTime value) {
    final monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[value.month - 1];
    return '${value.day.toString().padLeft(2, '0')} $month ${value.year}';
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(value)} $hour:$minute $period';
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

  Future<Classroom?> _getActiveHodDelegatedFinalApproval({
    required String classroomId,
    required String teacherId,
  }) async {
    final classroom = await _classroomService?.fetchClassroomById(classroomId);
    if (classroom == null || !classroom.hasActiveHodDelegation) {
      return null;
    }
    if (classroom.hodDelegatedFinalApproverId != teacherId) {
      return null;
    }
    return classroom;
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
