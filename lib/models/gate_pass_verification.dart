import 'gate_pass_request.dart';
import 'gate_pass_scan_log.dart';

enum GatePassVerificationStatus {
  approved,
  expired,
  alreadyUsed,
  notApproved,
  notFound,
  error,
}

class GatePassVerification {
  const GatePassVerification({
    required this.status,
    required this.passId,
    required this.message,
    required this.scannedAt,
    required this.historyLog,
    this.request,
    this.usedNow = false,
    this.wasOffline = false,
  });

  final GatePassVerificationStatus status;
  final String passId;
  final String message;
  final DateTime scannedAt;
  final GatePassRequest? request;
  final GatePassScanLog historyLog;
  final bool usedNow;
  final bool wasOffline;

  bool get isAllowed => status == GatePassVerificationStatus.approved;
}
