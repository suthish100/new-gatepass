import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class GatePassRequest {
  const GatePassRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.studentPhotoBase64,
    this.studentGender,
    required this.roomNumber,
    required this.studentClass,
    required this.department,
    required this.classroomId,
    required this.classroomSection,
    required this.teacherId,
    required this.hodId,
    required this.passType,
    required this.date,
    required this.outTime,
    required this.inTime,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.orgId,
    this.teacherActionAt,
    this.hodActionAt,
    this.approvedAt,
    this.usedAt,
    this.usedBy,
    this.usedByDevice,
    this.lastActionBy,
    this.cancelReason,
    this.teacherActionActorId,
    this.teacherActionActorName,
    this.teacherRoleUsedId,
    this.teacherRoleUsedName,
    this.teacherActionAuthorityReason,
    this.teacherDelegationRefId,
    this.fromDate,
    this.toDate,
    this.destination,
    this.parentContact,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String? studentPhotoBase64;
  final String? studentGender;
  final String roomNumber;
  final String studentClass;
  final String department;
  final String classroomId;
  final String classroomSection;
  final String teacherId;
  final String hodId;
  final String passType;
  final DateTime date;
  final String outTime;
  final String inTime;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? orgId;
  final DateTime? teacherActionAt;
  final DateTime? hodActionAt;
  final DateTime? approvedAt;
  final DateTime? usedAt;
  final String? usedBy;
  final String? usedByDevice;
  final String? lastActionBy;
  final String? cancelReason;
  final String? teacherActionActorId;
  final String? teacherActionActorName;
  final String? teacherRoleUsedId;
  final String? teacherRoleUsedName;
  final String? teacherActionAuthorityReason;
  final String? teacherDelegationRefId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? destination;
  final String? parentContact;

  bool get isOpen =>
      status == RequestStatus.pendingTeacher ||
      status == RequestStatus.forwardedToHod;

  bool get isApproved => status == RequestStatus.approved;

  bool get isLeavePass => passType == PassType.leave;

  bool get isUsed => usedAt != null;

  /// QR payload should only reveal the pass identity.
  String get qrData => id;

  bool isValidOn(DateTime moment) {
    final current = DateTime(moment.year, moment.month, moment.day);
    if (isLeavePass) {
      final start = fromDate ?? date;
      final end = toDate ?? fromDate ?? date;
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      return !current.isBefore(startDay) && !current.isAfter(endDay);
    }

    final passDay = DateTime(date.year, date.month, date.day);
    return current == passDay;
  }

  GatePassRequest copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentPhotoBase64,
    String? studentGender,
    String? roomNumber,
    String? studentClass,
    String? department,
    String? classroomId,
    String? classroomSection,
    String? teacherId,
    String? hodId,
    String? passType,
    DateTime? date,
    String? outTime,
    String? inTime,
    String? reason,
    String? status,
    DateTime? createdAt,
    String? orgId,
    DateTime? teacherActionAt,
    DateTime? hodActionAt,
    DateTime? approvedAt,
    DateTime? usedAt,
    String? usedBy,
    String? usedByDevice,
    String? lastActionBy,
    String? cancelReason,
    String? teacherActionActorId,
    String? teacherActionActorName,
    String? teacherRoleUsedId,
    String? teacherRoleUsedName,
    String? teacherActionAuthorityReason,
    String? teacherDelegationRefId,
    DateTime? fromDate,
    DateTime? toDate,
    String? destination,
    String? parentContact,
  }) {
    return GatePassRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhotoBase64: studentPhotoBase64 ?? this.studentPhotoBase64,
      studentGender: studentGender ?? this.studentGender,
      roomNumber: roomNumber ?? this.roomNumber,
      studentClass: studentClass ?? this.studentClass,
      department: department ?? this.department,
      classroomId: classroomId ?? this.classroomId,
      classroomSection: classroomSection ?? this.classroomSection,
      teacherId: teacherId ?? this.teacherId,
      hodId: hodId ?? this.hodId,
      passType: passType ?? this.passType,
      date: date ?? this.date,
      outTime: outTime ?? this.outTime,
      inTime: inTime ?? this.inTime,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      orgId: orgId ?? this.orgId,
      teacherActionAt: teacherActionAt ?? this.teacherActionAt,
      hodActionAt: hodActionAt ?? this.hodActionAt,
      approvedAt: approvedAt ?? this.approvedAt,
      usedAt: usedAt ?? this.usedAt,
      usedBy: usedBy ?? this.usedBy,
      usedByDevice: usedByDevice ?? this.usedByDevice,
      lastActionBy: lastActionBy ?? this.lastActionBy,
      cancelReason: cancelReason ?? this.cancelReason,
      teacherActionActorId: teacherActionActorId ?? this.teacherActionActorId,
      teacherActionActorName:
          teacherActionActorName ?? this.teacherActionActorName,
      teacherRoleUsedId: teacherRoleUsedId ?? this.teacherRoleUsedId,
      teacherRoleUsedName: teacherRoleUsedName ?? this.teacherRoleUsedName,
      teacherActionAuthorityReason:
          teacherActionAuthorityReason ?? this.teacherActionAuthorityReason,
      teacherDelegationRefId:
          teacherDelegationRefId ?? this.teacherDelegationRefId,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      destination: destination ?? this.destination,
      parentContact: parentContact ?? this.parentContact,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhotoBase64': studentPhotoBase64,
      'studentGender': studentGender,
      'roomNumber': roomNumber,
      'registerNumber': roomNumber,
      'studentClass': studentClass,
      'department': department,
      'classroomId': classroomId,
      'classroomSection': classroomSection,
      'teacherId': teacherId,
      'hodId': hodId,
      'passType': passType,
      'date': Timestamp.fromDate(date),
      'outTime': outTime,
      'inTime': inTime,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'orgId': orgId,
      'teacherActionAt': teacherActionAt == null
          ? null
          : Timestamp.fromDate(teacherActionAt!),
      'hodActionAt': hodActionAt == null
          ? null
          : Timestamp.fromDate(hodActionAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'usedAt': usedAt == null ? null : Timestamp.fromDate(usedAt!),
      'usedBy': usedBy,
      'usedByDevice': usedByDevice,
      'lastActionBy': lastActionBy,
      'cancelReason': cancelReason,
      'teacherActionActorId': teacherActionActorId,
      'teacherActionActorName': teacherActionActorName,
      'teacherRoleUsedId': teacherRoleUsedId,
      'teacherRoleUsedName': teacherRoleUsedName,
      'teacherActionAuthorityReason': teacherActionAuthorityReason,
      'teacherDelegationRefId': teacherDelegationRefId,
      'fromDate': fromDate == null ? null : Timestamp.fromDate(fromDate!),
      'toDate': toDate == null ? null : Timestamp.fromDate(toDate!),
      'destination': destination,
      'parentContact': parentContact,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhotoBase64': studentPhotoBase64,
      'studentGender': studentGender,
      'roomNumber': roomNumber,
      'registerNumber': roomNumber,
      'studentClass': studentClass,
      'department': department,
      'classroomId': classroomId,
      'classroomSection': classroomSection,
      'teacherId': teacherId,
      'hodId': hodId,
      'passType': passType,
      'date': date.toIso8601String(),
      'outTime': outTime,
      'inTime': inTime,
      'reason': reason,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'orgId': orgId,
      'teacherActionAt': teacherActionAt?.toIso8601String(),
      'hodActionAt': hodActionAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'usedAt': usedAt?.toIso8601String(),
      'usedBy': usedBy,
      'usedByDevice': usedByDevice,
      'lastActionBy': lastActionBy,
      'cancelReason': cancelReason,
      'teacherActionActorId': teacherActionActorId,
      'teacherActionActorName': teacherActionActorName,
      'teacherRoleUsedId': teacherRoleUsedId,
      'teacherRoleUsedName': teacherRoleUsedName,
      'teacherActionAuthorityReason': teacherActionAuthorityReason,
      'teacherDelegationRefId': teacherDelegationRefId,
      'fromDate': fromDate?.toIso8601String(),
      'toDate': toDate?.toIso8601String(),
      'destination': destination,
      'parentContact': parentContact,
    };
  }

  factory GatePassRequest.fromJson(Map<String, dynamic> json) {
    return GatePassRequest.fromMap(json, json['id'] as String? ?? '');
  }

  factory GatePassRequest.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final status = map['status'] as String? ?? RequestStatus.pendingTeacher;

    return GatePassRequest(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName:
          map['studentName'] as String? ?? map['name'] as String? ?? '',
      studentPhotoBase64: map['studentPhotoBase64'] as String?,
      studentGender: map['studentGender'] as String?,
      roomNumber:
          map['roomNumber'] as String? ?? map['registerNumber'] as String? ?? '',
      studentClass: map['studentClass'] as String? ?? '',
      department: map['department'] as String? ?? '',
      classroomId: map['classroomId'] as String? ?? '',
      classroomSection: map['classroomSection'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      hodId: map['hodId'] as String? ?? '',
      passType: map['passType'] as String? ?? PassType.outing,
      date: parseDate(map['date']),
      outTime: map['outTime'] as String? ?? '',
      inTime: map['inTime'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: status,
      createdAt: parseDate(map['createdAt']),
      orgId: map['orgId'] as String?,
      teacherActionAt: parseOptionalDate(map['teacherActionAt']),
      hodActionAt: parseOptionalDate(map['hodActionAt']),
      approvedAt: parseOptionalDate(map['approvedAt']),
      usedAt: parseOptionalDate(map['usedAt']),
      usedBy: map['usedBy'] as String?,
      usedByDevice: map['usedByDevice'] as String?,
      lastActionBy: map['lastActionBy'] as String?,
      cancelReason: map['cancelReason'] as String?,
      teacherActionActorId: map['teacherActionActorId'] as String?,
      teacherActionActorName: map['teacherActionActorName'] as String?,
      teacherRoleUsedId: map['teacherRoleUsedId'] as String?,
      teacherRoleUsedName: map['teacherRoleUsedName'] as String?,
      teacherActionAuthorityReason:
          map['teacherActionAuthorityReason'] as String?,
      teacherDelegationRefId: map['teacherDelegationRefId'] as String?,
      fromDate: parseOptionalDate(map['fromDate']),
      toDate: parseOptionalDate(map['toDate']),
      destination: map['destination'] as String?,
      parentContact: map['parentContact'] as String?,
    );
  }
}
