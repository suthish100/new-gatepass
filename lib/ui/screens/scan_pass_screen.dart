import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/gate_pass_request.dart';
import '../../models/gate_pass_scan_log.dart';
import '../../models/gate_pass_verification.dart';
import '../../services/gate_pass_service.dart';

class ScanPassScreen extends StatefulWidget {
  const ScanPassScreen({super.key, required this.gatePassService});

  final GatePassService gatePassService;

  @override
  State<ScanPassScreen> createState() => _ScanPassScreenState();
}

class _ScanPassScreenState extends State<ScanPassScreen> {
  final TextEditingController _controller = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _loading = false;
  bool _syncing = false;
  GatePassVerification? _result;
  List<GatePassScanLog> _history = <GatePassScanLog>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInputChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onInputChanged)
      ..dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    await _syncOfflineLogs(showIndicator: false);
    await _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final history = await widget.gatePassService.fetchRecentScanHistory(
      limit: 8,
    );
    if (!mounted) return;
    setState(() {
      _history = history;
    });
  }

  Future<void> _syncOfflineLogs({bool showIndicator = true}) async {
    if (showIndicator && mounted) {
      setState(() {
        _syncing = true;
      });
    }
    try {
      await widget.gatePassService.syncPendingOfflineScans();
    } finally {
      await _refreshHistory();
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _handleScan(String rawCode, {required String source}) async {
    if (_loading) return;
    final normalized = rawCode.trim();
    if (normalized.isEmpty) return;

    if (source == 'camera') {
      await _scannerController.stop();
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    final verification = await widget.gatePassService.verifyPassForScan(
      rawCode: normalized,
      scanSource: source,
    );

    if (!mounted) return;

    setState(() {
      _result = verification;
      _loading = false;
      _controller.text = verification.passId;
    });
    await _refreshHistory();
  }

  Future<void> _submitManualScan() async {
    await _handleScan(_controller.text, source: 'manual');
  }

  Future<void> _scanAnother() async {
    setState(() {
      _result = null;
      _loading = false;
      _controller.clear();
    });
    await _scannerController.start();
    await _refreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        title: Text(
          _result == null ? 'Security Gate Verification' : 'Gate Decision',
        ),
        actions: [
          IconButton(
            tooltip: 'Sync offline logs',
            onPressed: _syncing ? null : () => _syncOfflineLogs(),
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _result == null
              ? _buildScannerBody()
              : _buildResultBody(_result!),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    final result = _result;
    if (result == null) {
      return const Color(0xFF0E1726);
    }
    if (result.isAllowed) {
      return const Color(0xFF0D6B3D);
    }
    return const Color(0xFF861B1B);
  }

  Widget _buildScannerBody() {
    return SingleChildScrollView(
      key: const ValueKey<String>('scanner-body'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live QR Scan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Student shows QR, security scans, and the app checks approval, expiry, and one-time use.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    fit: BoxFit.cover,
                    onDetect: (BarcodeCapture capture) {
                      if (_loading) return;
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final raw = barcodes.first.rawValue;
                      if (raw == null || raw.trim().isEmpty) return;
                      _handleScan(raw, source: 'camera');
                    },
                  ),
                  Container(color: Colors.black.withAlpha(55)),
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  if (_loading)
                    Container(
                      color: Colors.black.withAlpha(150),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF162236),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual Fallback',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Pass ID',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withAlpha(8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => _controller.clear(),
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white70,
                            ),
                          ),
                  ),
                  onSubmitted: (_) => _submitManualScan(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submitManualScan,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verify Pass'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Offline fallback is enabled. Approved passes already cached on this gate device can still be verified and synced later.',
              style: TextStyle(
                color: Color(0xFF6C5400),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Recent Scan History',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              if (_history.isNotEmpty)
                Text(
                  '${_history.length} shown',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No scan history yet.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            ..._history.map(_buildHistoryTile),
        ],
      ),
    );
  }

  Widget _buildResultBody(GatePassVerification result) {
    final request = result.request;
    final bool success = result.isAllowed;
    final Color panelColor = success
        ? const Color(0xFF0A5C34)
        : const Color(0xFF6E1818);

    return SingleChildScrollView(
      key: ValueKey<String>('result-${result.status.name}'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Icon(
                      success ? Icons.verified : Icons.block,
                      color: Colors.white,
                      size: 76,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      success ? 'ALLOW EXIT' : 'STOP STUDENT',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 30,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (request != null) _buildStudentIdentity(request),
                    if (request != null) const SizedBox(height: 18),
                    if (request != null)
                      _buildVerificationDetails(request, result),
                    if (request == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(14),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Pass ID: ${result.passId.isEmpty ? '-' : result.passId}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _badge(
                          result.wasOffline ? 'OFFLINE CACHE' : 'LIVE FIREBASE',
                        ),
                        if (result.usedNow) _badge('ONE-TIME LOCKED'),
                        _badge(DateFormat('hh:mm a').format(result.scannedAt)),
                      ],
                    ),
                  ],
                ),
                if (success)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.rotate(
                          angle: -0.28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withAlpha(220),
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withAlpha(18),
                            ),
                            child: const Text(
                              'HOD APPROVED',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanAnother,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Another'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentIdentity(GatePassRequest request) {
    final photoBytes = _decodeBase64(request.studentPhotoBase64);
    return Row(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: Colors.white.withAlpha(22),
          backgroundImage: photoBytes == null ? null : MemoryImage(photoBytes),
          child: photoBytes == null
              ? const Icon(Icons.person, size: 36, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.studentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.registerNumber,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${request.department} | ${request.studentClass}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationDetails(
    GatePassRequest request,
    GatePassVerification result,
  ) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Reason', request.reason),
      MapEntry('Pass ID', request.id),
      MapEntry(
        request.isLeavePass ? 'From' : 'Date',
        DateFormat('dd MMM yyyy').format(
          request.isLeavePass
              ? (request.fromDate ?? request.date)
              : request.date,
        ),
      ),
      if (request.isLeavePass)
        MapEntry(
          'To',
          DateFormat('dd MMM yyyy').format(request.toDate ?? request.date),
        ),
      if (!request.isLeavePass) MapEntry('Out', request.outTime),
      if (!request.isLeavePass) MapEntry('In', request.inTime),
      if (request.isUsed)
        MapEntry(
          'Scanned',
          DateFormat('dd MMM yyyy, hh:mm a').format(request.usedAt!),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: rows
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHistoryTile(GatePassScanLog log) {
    final success = log.outcome == GatePassVerificationStatus.approved.name;
    final tileColor = success
        ? const Color(0xFF123D28)
        : const Color(0xFF3B1717);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: success ? Colors.green : Colors.red,
            child: Icon(
              success ? Icons.check : Icons.close,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.studentName ?? log.passId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.message,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('hh:mm a').format(log.scannedAt),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (log.pendingSync)
                const Text(
                  'Pending sync',
                  style: TextStyle(color: Colors.amber, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeBase64(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
