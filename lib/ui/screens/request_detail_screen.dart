import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../models/gate_pass_request.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
  });

  final GatePassRequest request;
  final Future<void> Function()? onApprove;
  final Future<void> Function()? onReject;

  bool get _isLeavePass => request.isLeavePass;
  bool get _isRejected =>
      request.status == RequestStatus.rejectedByTeacher ||
      request.status == RequestStatus.rejectedByHod;

  String _labelForStatus(String status) {
    switch (status) {
      case RequestStatus.pendingTeacher:
        return 'Pending Class Incharge';
      case RequestStatus.forwardedToHod:
        return 'Pending HOD';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejectedByTeacher:
        return 'Rejected by Class Incharge';
      case RequestStatus.rejectedByHod:
        return 'Rejected by HOD';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final hasActions = onApprove != null || onReject != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Student Request Form')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    request.studentName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text('Register No: ${request.registerNumber}'),
                  Text('Class: ${request.classroomSection}'),
                  Text('Department: ${request.department}'),
                  const SizedBox(height: 8),
                  Chip(label: Text(_labelForStatus(request.status))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _detailRow('Pass Type', request.passType),
                  if (_isLeavePass) ...<Widget>[
                    _detailRow(
                      'From Date',
                      request.fromDate == null
                          ? '-'
                          : dateFormat.format(request.fromDate!),
                    ),
                    _detailRow(
                      'To Date',
                      request.toDate == null
                          ? '-'
                          : dateFormat.format(request.toDate!),
                    ),
                    _detailRow(
                      'Destination',
                      (request.destination ?? '').isEmpty
                          ? '-'
                          : request.destination!,
                    ),
                    _detailRow(
                      'Parent Contact',
                      (request.parentContact ?? '').isEmpty
                          ? '-'
                          : request.parentContact!,
                    ),
                  ] else ...<Widget>[
                    _detailRow('Date', dateFormat.format(request.date)),
                    _detailRow('Out Time', request.outTime),
                    _detailRow('In Time', request.inTime),
                  ],
                  _detailRow('Reason', request.reason),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _detailRow(
                    'Requested At',
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(request.createdAt),
                  ),
                  _detailRow(
                    'Teacher Action',
                    request.teacherActionAt == null
                        ? '-'
                        : DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(request.teacherActionAt!),
                  ),
                  _detailRow(
                    'HOD Action',
                    request.hodActionAt == null
                        ? '-'
                        : DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(request.hodActionAt!),
                  ),
                  _detailRow(
                    'Last Action By',
                    (request.lastActionBy ?? '').isEmpty
                        ? '-'
                        : request.lastActionBy!,
                  ),
                  if ((request.teacherActionAuthorityReason ?? '').isNotEmpty)
                    _detailRow(
                      'Approval Notes',
                      request.teacherActionAuthorityReason!,
                    ),
                  _detailRow(
                    _isRejected ? 'Rejection Reason' : 'Cancel Reason',
                    (request.cancelReason ?? '').isEmpty
                        ? '-'
                        : request.cancelReason!,
                  ),
                ],
              ),
            ),
          ),
          if (hasActions) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async => onReject!(),
                      child: const Text('Reject'),
                    ),
                  ),
                if (onReject != null && onApprove != null)
                  const SizedBox(width: 10),
                if (onApprove != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async => onApprove!(),
                      child: const Text('Approve'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
