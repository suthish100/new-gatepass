import 'package:cloud_firestore/cloud_firestore.dart';

class GatePassRequest {
  const GatePassRequest({
    required this.id,
    required this.studentId,
    required this.name,
    required this.registerNumber,
    required this.studentClass,
    required this.department,
    required this.date,
    required this.inTime,
    required this.outTime,
    required this.place,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.lastActionBy,
  });

  final String id;
  final String studentId;
  final String name;
  final String registerNumber;
  final String studentClass;
  final String department;
  final DateTime date;
  final String inTime;
  final String outTime;
  final String place;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String? lastActionBy;

  GatePassRequest copyWith({
    String? id,
    String? studentId,
    String? name,
    String? registerNumber,
    String? studentClass,
    String? department,
    DateTime? date,
    String? inTime,
    String? outTime,
    String? place,
    String? reason,
    String? status,
    DateTime? createdAt,
    String? lastActionBy,
  }) {
    return GatePassRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      registerNumber: registerNumber ?? this.registerNumber,
      studentClass: studentClass ?? this.studentClass,
      department: department ?? this.department,
      date: date ?? this.date,
      inTime: inTime ?? this.inTime,
      outTime: outTime ?? this.outTime,
      place: place ?? this.place,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastActionBy: lastActionBy ?? this.lastActionBy,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'studentId': studentId,
      'name': name,
      'registerNumber': registerNumber,
      'studentClass': studentClass,
      'department': department,
      'date': Timestamp.fromDate(date),
      'inTime': inTime,
      'outTime': outTime,
      'place': place,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActionBy': lastActionBy,
    };
  }

  factory GatePassRequest.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return DateTime.now();
    }

    return GatePassRequest(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      registerNumber: map['registerNumber'] as String? ?? '',
      studentClass: map['studentClass'] as String? ?? '',
      department: map['department'] as String? ?? '',
      date: parseDate(map['date']),
      inTime: map['inTime'] as String? ?? '',
      outTime: map['outTime'] as String? ?? '',
      place: map['place'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      lastActionBy: map['lastActionBy'] as String?,
    );
  }
}
