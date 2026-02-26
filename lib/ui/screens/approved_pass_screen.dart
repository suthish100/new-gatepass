import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/gate_pass_request.dart';

/// Displays the approved digital gate pass card with QR code.
/// For outing pass: shows date, in/out time, reason.
/// For leave pass: shows formal letter style with dates and destination.
class ApprovedPassScreen extends StatelessWidget {
  const ApprovedPassScreen({super.key, required this.request});

  final GatePassRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLeave = request.isLeavePass;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
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
            // Approved banner
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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

            // Pass card body
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.studentName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Reg: ${request.registerNumber}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLeave
                              ? Colors.orange.shade50
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLeave
                                ? Colors.orange.shade300
                                : Colors.blue.shade300,
                          ),
                        ),
                        child: Text(
                          request.passType,
                          style: TextStyle(
                            color: isLeave
                                ? Colors.orange.shade800
                                : Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
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

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),

                  if (isLeave) ...[
                    // ─── Leave Pass Letter Style ───────────────────────────────
                    _sectionTitle(context, '📋 Leave Permission Details'),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      'From Date',
                      request.fromDate != null
                          ? dateFormat.format(request.fromDate!)
                          : '—',
                    ),
                    _infoRow(
                      context,
                      'To Date',
                      request.toDate != null
                          ? dateFormat.format(request.toDate!)
                          : '—',
                    ),
                    if (request.fromDate != null && request.toDate != null)
                      _infoRow(
                        context,
                        'Duration',
                        '${request.toDate!.difference(request.fromDate!).inDays + 1} day(s)',
                      ),
                    _infoRow(
                      context,
                      'Destination',
                      request.destination ?? '—',
                    ),
                    if ((request.parentContact ?? '').isNotEmpty)
                      _infoRow(
                        context,
                        'Parent Contact',
                        request.parentContact!,
                      ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'This is to certify that the above-mentioned student has been granted leave '
                        'for the specified period. The student is permitted to leave the campus and '
                        'return on the date mentioned above.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade900,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ] else ...[
                    // ─── Outing Pass Details ───────────────────────────────────
                    _sectionTitle(context, '🚪 Outing Pass Details'),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      'Date',
                      dateFormat.format(request.date),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoRow(
                            context,
                            'Out Time',
                            request.outTime,
                          ),
                        ),
                        Expanded(
                          child: _infoRow(
                            context,
                            'In Time',
                            request.inTime,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  _infoRow(context, 'Reason', request.reason),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),

                  // Approval trail
                  _sectionTitle(context, '✅ Approval Trail'),
                  const SizedBox(height: 10),
                  _approvalStep(
                    context,
                    step: '1',
                    label: 'Class Incharge Approved',
                    time: request.teacherActionAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(request.teacherActionAt!)
                        : null,
                    done: request.teacherActionAt != null,
                  ),
                  const SizedBox(height: 8),
                  _approvalStep(
                    context,
                    step: '2',
                    label: 'HOD Final Approved',
                    time: request.hodActionAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                            .format(request.hodActionAt!)
                        : null,
                    done: request.hodActionAt != null,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(),
                  ),

                  // QR Code
                  _sectionTitle(context, '📱 Gate Pass QR Code'),
                  const SizedBox(height: 6),
                  const Text(
                    'Show this QR code to security for verification.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: QrImageView(
                        data: request.qrData,
                        version: QrVersions.auto,
                        size: 200,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Pass ID: ${request.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Validity note for outing pass
                  if (!isLeave)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠️ This outing pass is valid only for '
                        '${dateFormat.format(request.date)}. '
                        'Using it on any other date will be rejected at the gate.',
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

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalStep(
    BuildContext context, {
    required String step,
    required String label,
    required bool done,
    String? time,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? Colors.green.shade100 : Colors.grey.shade200,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, color: Colors.green.shade700, size: 16)
                : Text(
                    step,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  fontWeight: FontWeight.w500,
                  color: done ? Colors.green.shade800 : Colors.grey.shade600,
                ),
              ),
              if (time != null)
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
