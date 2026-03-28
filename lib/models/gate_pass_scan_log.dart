import 'package:cloud_firestore/cloud_firestore.dart';

class GatePassScanLog {
  const GatePassScanLog({
    required this.id,
    required this.passId,
    required this.outcome,
    required this.message,
    required this.scannedAt,
    required this.scanSource,
    required this.wasOffline,
    required this.pendingSync,
    this.studentId,
    this.studentName,
    this.roomNumber,
    this.passType,
  });

  final String id;
  final String passId;
  final String outcome;
  final String message;
  final DateTime scannedAt;
  final String scanSource;
  final bool wasOffline;
  final bool pendingSync;
  final String? studentId;
  final String? studentName;
  final String? roomNumber;
  final String? passType;

  GatePassScanLog copyWith({
    String? id,
    String? passId,
    String? outcome,
    String? message,
    DateTime? scannedAt,
    String? scanSource,
    bool? wasOffline,
    bool? pendingSync,
    String? studentId,
    String? studentName,
    String? roomNumber,
    String? passType,
  }) {
    return GatePassScanLog(
      id: id ?? this.id,
      passId: passId ?? this.passId,
      outcome: outcome ?? this.outcome,
      message: message ?? this.message,
      scannedAt: scannedAt ?? this.scannedAt,
      scanSource: scanSource ?? this.scanSource,
      wasOffline: wasOffline ?? this.wasOffline,
      pendingSync: pendingSync ?? this.pendingSync,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      roomNumber: roomNumber ?? this.roomNumber,
      passType: passType ?? this.passType,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'passId': passId,
      'outcome': outcome,
      'message': message,
      'scannedAt': Timestamp.fromDate(scannedAt),
      'scanSource': scanSource,
      'wasOffline': wasOffline,
      'pendingSync': pendingSync,
      'studentId': studentId,
      'studentName': studentName,
      'roomNumber': roomNumber,
      'registerNumber': roomNumber,
      'passType': passType,
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'passId': passId,
      'outcome': outcome,
      'message': message,
      'scannedAt': scannedAt.toIso8601String(),
      'scanSource': scanSource,
      'wasOffline': wasOffline,
      'pendingSync': pendingSync,
      'studentId': studentId,
      'studentName': studentName,
      'roomNumber': roomNumber,
      'registerNumber': roomNumber,
      'passType': passType,
    };
  }

  factory GatePassScanLog.fromJson(Map<String, dynamic> json) {
    return GatePassScanLog(
      id: json['id'] as String? ?? '',
      passId: json['passId'] as String? ?? '',
      outcome: json['outcome'] as String? ?? 'error',
      message: json['message'] as String? ?? '',
      scannedAt:
          DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
          DateTime.now(),
      scanSource: json['scanSource'] as String? ?? 'manual',
      wasOffline: json['wasOffline'] as bool? ?? false,
      pendingSync: json['pendingSync'] as bool? ?? false,
      studentId: json['studentId'] as String?,
      studentName: json['studentName'] as String?,
      roomNumber:
          json['roomNumber'] as String? ?? json['registerNumber'] as String?,
      passType: json['passType'] as String?,
    );
  }
}
