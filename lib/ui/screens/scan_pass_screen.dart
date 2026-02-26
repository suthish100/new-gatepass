import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/gate_pass_request.dart';
import '../../services/gate_pass_service.dart';
import '../../services/firebase_bootstrap.dart';

/// QR Scanner screen for security guards.
/// No login required — accessible from the welcome screen.
/// Manually enter a pass ID to verify (camera scanner package not added;
/// this uses manual entry + Firestore lookup).
class ScanPassScreen extends StatefulWidget {
  const ScanPassScreen({
    super.key,
    required this.gatePassService,
  });

  final GatePassService gatePassService;

  @override
  State<ScanPassScreen> createState() => _ScanPassScreenState();
}

class _ScanPassScreenState extends State<ScanPassScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  _ScanResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      // Handle QR data format: "EGATEPASS|passId|studentId|status"
      String passId = input;
      if (input.startsWith('EGATEPASS|')) {
        final parts = input.split('|');
        if (parts.length >= 2) passId = parts[1];
      }

      final pass = await widget.gatePassService.fetchPassById(passId);
      if (!mounted) return;

      if (pass == null) {
        setState(() {
          _result = _ScanResult.notFound();
          _loading = false;
        });
        return;
      }

      // Flaw 8 fix: Validate date for outing passes
      if (!pass.isLeavePass) {
        final today = DateTime.now();
        final passDate = pass.date;
        final isToday = passDate.year == today.year &&
            passDate.month == today.month &&
            passDate.day == today.day;
        if (pass.isApproved && !isToday) {
          setState(() {
            _result = _ScanResult.expired(pass);
            _loading = false;
          });
          return;
        }
      }

      setState(() {
        _result = _ScanResult.fromRequest(pass);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _ScanResult.error(e.toString());
        _loading = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text(
          'Gate Pass Verification',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner,
                  color: Colors.white70, size: 80),
              const SizedBox(height: 12),
              const Text(
                'Security Gate Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the Pass ID from the student\'s gate pass\nor scan the QR code.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Input field
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Pass ID or QR Code Data',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white60),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white60),
                          onPressed: _reset,
                        )
                      : null,
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_outlined),
                  label:
                      Text(_loading ? 'Checking...' : 'Verify Pass'),
                  onPressed: _loading ? null : _verify,
                ),
              ),

              const SizedBox(height: 32),

              // Result card
              if (_result != null) _buildResultCard(_result!),

              if (!FirebaseBootstrap.isReady) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade900.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ Offline mode — pass verification uses local data only.',
                    style: TextStyle(color: Colors.yellow, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(_ScanResult result) {
    Color cardColor;
    Color headerColor;
    IconData headerIcon;
    String headerText;

    if (result.type == _ResultType.approved) {
      cardColor = const Color(0xFF0D4A2C);
      headerColor = Colors.green;
      headerIcon = Icons.check_circle;
      headerText = 'APPROVED ✓';
    } else if (result.type == _ResultType.expired) {
      cardColor = const Color(0xFF4A3D0D);
      headerColor = Colors.orange;
      headerIcon = Icons.warning_amber;
      headerText = 'PASS EXPIRED';
    } else if (result.type == _ResultType.rejected) {
      cardColor = const Color(0xFF4A0D0D);
      headerColor = Colors.red;
      headerIcon = Icons.cancel;
      headerText = 'NOT APPROVED ✗';
    } else {
      cardColor = const Color(0xFF2A2A3A);
      headerColor = Colors.grey;
      headerIcon = Icons.help_outline;
      headerText = 'PASS NOT FOUND';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headerColor.withAlpha(150), width: 2),
      ),
      child: Column(
        children: [
          // Status header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: headerColor.withAlpha(50),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(headerIcon, color: headerColor, size: 32),
                const SizedBox(width: 10),
                Text(
                  headerText,
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Pass details
          if (result.request != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _detailRow('Name', result.request!.studentName),
                  _detailRow('Reg No.', result.request!.registerNumber),
                  _detailRow('Department', result.request!.department),
                  _detailRow('Class', result.request!.studentClass),
                  _detailRow('Pass Type', result.request!.passType),
                  if (result.request!.isLeavePass) ...[
                    _detailRow(
                      'From',
                      result.request!.fromDate != null
                          ? DateFormat('dd MMM yyyy').format(result.request!.fromDate!)
                          : '—',
                    ),
                    _detailRow(
                      'To',
                      result.request!.toDate != null
                          ? DateFormat('dd MMM yyyy').format(result.request!.toDate!)
                          : '—',
                    ),
                    _detailRow('Destination', result.request!.destination ?? '—'),
                  ] else ...[
                    _detailRow(
                      'Date',
                      DateFormat('dd MMM yyyy').format(result.request!.date),
                    ),
                    _detailRow('Out Time', result.request!.outTime),
                    _detailRow('In Time', result.request!.inTime),
                  ],
                  _detailRow('Reason', result.request!.reason),
                  if (result.type == _ResultType.expired)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(40),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠️ This pass was valid for '
                        '${DateFormat('dd MMM yyyy').format(result.request!.date)} only.',
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                result.message ?? 'No pass found with this ID.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt, color: Colors.white60),
              label: const Text(
                'Scan Another',
                style: TextStyle(color: Colors.white60),
              ),
              onPressed: _reset,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Internal result model ──────────────────────────────────────────────────

enum _ResultType { approved, expired, rejected, notFound, error }

class _ScanResult {
  _ScanResult({
    required this.type,
    this.request,
    this.message,
  });

  final _ResultType type;
  final GatePassRequest? request;
  final String? message;

  factory _ScanResult.fromRequest(GatePassRequest pass) {
    if (pass.isApproved) {
      return _ScanResult(type: _ResultType.approved, request: pass);
    }
    if (pass.status == RequestStatus.rejectedByTeacher ||
        pass.status == RequestStatus.rejectedByHod) {
      return _ScanResult(type: _ResultType.rejected, request: pass);
    }
    return _ScanResult(
      type: _ResultType.rejected,
      request: pass,
      message: 'Pass status: ${pass.status}',
    );
  }

  factory _ScanResult.expired(GatePassRequest pass) {
    return _ScanResult(type: _ResultType.expired, request: pass);
  }

  factory _ScanResult.notFound() {
    return _ScanResult(
      type: _ResultType.notFound,
      message: 'No pass found with this ID. It may be invalid or not yet created.',
    );
  }

  factory _ScanResult.error(String message) {
    return _ScanResult(
      type: _ResultType.error,
      message: 'Error: $message',
    );
  }
}
