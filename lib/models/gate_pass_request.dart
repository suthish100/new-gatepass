import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class GatePassRequest {
  const GatePassRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.registerNumber,
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
    this.teacherActionAt,
    this.hodActionAt,
    this.approvedAt,
    this.lastActionBy,
    this.cancelReason,
    // Leave / Native pass specific fields
    this.fromDate,
    this.toDate,
    this.destination,
    this.parentContact,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String registerNumber;
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
  final DateTime? teacherActionAt;
  final DateTime? hodActionAt;
  final DateTime? approvedAt;
  final String? lastActionBy;
  final String? cancelReason;

  // Leave pass fields
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? destination;
  final String? parentContact;

  bool get isOpen =>
      status == RequestStatus.pendingTeacher ||
      status == RequestStatus.forwardedToHod;

  bool get isApproved => status == RequestStatus.approved;

  bool get isLeavePass => passType == PassType.leave;

  /// QR data string — encodes the pass identity for gate security scanning
  String get qrData => 'EGATEPASS|$id|$studentId|$status';

  GatePassRequest copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? registerNumber,
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
    DateTime? teacherActionAt,
    DateTime? hodActionAt,
    DateTime? approvedAt,
    String? lastActionBy,
    String? cancelReason,
    DateTime? fromDate,
    DateTime? toDate,
    String? destination,
    String? parentContact,
  }) {
    return GatePassRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      registerNumber: registerNumber ?? this.registerNumber,
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
      teacherActionAt: teacherActionAt ?? this.teacherActionAt,
      hodActionAt: hodActionAt ?? this.hodActionAt,
      approvedAt: approvedAt ?? this.approvedAt,
      lastActionBy: lastActionBy ?? this.lastActionBy,
      cancelReason: cancelReason ?? this.cancelReason,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      destination: destination ?? this.destination,
      parentContact: parentContact ?? this.parentContact,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'studentId': studentId,
      'studentName': studentName,
      'registerNumber': registerNumber,
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
      'teacherActionAt':
          teacherActionAt == null ? null : Timestamp.fromDate(teacherActionAt!),
      'hodActionAt': hodActionAt == null ? null : Timestamp.fromDate(hodActionAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'lastActionBy': lastActionBy,
      'cancelReason': cancelReason,
      'fromDate': fromDate == null ? null : Timestamp.fromDate(fromDate!),
      'toDate': toDate == null ? null : Timestamp.fromDate(toDate!),
      'destination': destination,
      'parentContact': parentContact,
    };
  }

  factory GatePassRequest.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final status = map['status'] as String? ?? RequestStatus.pendingTeacher;

    return GatePassRequest(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? map['name'] as String? ?? '',
      registerNumber: map['registerNumber'] as String? ?? '',
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
      teacherActionAt: parseOptionalDate(map['teacherActionAt']),
      hodActionAt: parseOptionalDate(map['hodActionAt']),
      approvedAt: parseOptionalDate(map['approvedAt']),
      lastActionBy: map['lastActionBy'] as String?,
      cancelReason: map['cancelReason'] as String?,
      fromDate: parseOptionalDate(map['fromDate']),
      toDate: parseOptionalDate(map['toDate']),
      destination: map['destination'] as String?,
      parentContact: map['parentContact'] as String?,
    );
  }
}
