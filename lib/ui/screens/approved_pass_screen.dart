import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/gate_pass_request.dart';

class ApprovedPassScreen extends StatelessWidget {
  const ApprovedPassScreen({super.key, required this.request});

  final GatePassRequest request;

  Uint8List? get _photoBytes {
    final encoded = request.studentPhotoBase64;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLeave = request.isLeavePass;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(isLeave ? 'Leave Permission Pass' : 'Gate Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Copy pass ID',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: request.id));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pass ID copied to clipboard.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0F8F53), Color(0xFF1FA971)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 26),
                  SizedBox(width: 8),
                  Text(
                    'APPROVED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _studentPhotoCard(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: _typeChip(isLeave),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              request.studentName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Room No: ${request.roomNumber}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${request.department} | ${request.studentClass}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              request.classroomSection,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  if (isLeave) ...[
                    _sectionTitle(context, 'Leave Permission Details'),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      'From Date',
                      request.fromDate != null
                          ? dateFormat.format(request.fromDate!)
                          : '-',
                    ),
                    _infoRow(
                      context,
                      'To Date',
                      request.toDate != null
                          ? dateFormat.format(request.toDate!)
                          : '-',
                    ),
                    _infoRow(
                      context,
                      'Destination',
                      request.destination ?? '-',
                    ),
                    if ((request.parentContact ?? '').isNotEmpty)
                      _infoRow(
                        context,
                        'Parent Contact',
                        request.parentContact!,
                      ),
                  ] else ...[
                    _sectionTitle(context, 'Outing Pass Details'),
                    const SizedBox(height: 10),
                    _infoRow(context, 'Date', dateFormat.format(request.date)),
                    _infoRow(context, 'Out Time', request.outTime),
                    _infoRow(context, 'In Time', request.inTime),
                  ],
                  const SizedBox(height: 10),
                  _infoRow(context, 'Reason', request.reason),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  _sectionTitle(context, 'Approval Trail'),
                  const SizedBox(height: 10),
                  _approvalStep(
                    context,
                    label: 'Class Incharge Approved',
                    done: request.teacherActionAt != null,
                    time: request.teacherActionAt == null
                        ? null
                        : DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(request.teacherActionAt!),
                  ),
                  const SizedBox(height: 8),
                  _approvalStep(
                    context,
                    label: 'HOD Final Approved',
                    done: request.hodActionAt != null,
                    time: request.hodActionAt == null
                        ? null
                        : DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(request.hodActionAt!),
                  ),
                  if (request.isUsed) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE86A61)),
                      ),
                      child: Text(
                        'Already used at ${DateFormat('dd MMM yyyy, hh:mm a').format(request.usedAt!)}',
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),
                  _sectionTitle(context, 'Security QR'),
                  const SizedBox(height: 6),
                  const Text(
                    'This QR contains only the secure pass ID.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: QrImageView(
                        data: request.qrData,
                        version: QrVersions.auto,
                        size: 210,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Pass ID: ${request.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isLeave
                          ? 'Security will verify this pass in real time before allowing exit.'
                          : 'This outing pass is valid only on ${dateFormat.format(request.date)}.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentPhotoCard() {
    final photoBytes = _photoBytes;
    return Container(
      width: 108,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCAE8D4)),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFE7F5ED),
              image: photoBytes == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(photoBytes),
                      fit: BoxFit.cover,
                    ),
            ),
            child: photoBytes == null
                ? const Icon(Icons.person, size: 44, color: Color(0xFF0F8F53))
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Student Photo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F8F53),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(bool isLeave) {
    final accent = isLeave ? Colors.orange : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.shade300),
      ),
      child: Text(
        request.passType,
        style: TextStyle(
          color: accent.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalStep(
    BuildContext context, {
    required String label,
    required bool done,
    String? time,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: done ? Colors.green.shade100 : Colors.grey.shade200,
          child: Icon(
            done ? Icons.check : Icons.schedule,
            color: done ? Colors.green.shade700 : Colors.grey.shade600,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: done ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
              if (time != null)
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
